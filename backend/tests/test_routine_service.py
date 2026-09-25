"""파이프라인 B ①⑥⑦ 단위 테스트. Supabase·OpenAI는 가짜로 대체한다."""

import asyncio
import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from httpx import ASGITransport, AsyncClient
from postgrest.exceptions import APIError

from app.api.v1.family import get_family_service
from app.api.v1.routine import get_routine_service, warmup_routine
from app.core.config import Settings
from app.core.security import CurrentUser, get_current_user
from app.domains.family.service import FamilyService
from app.domains.family.stub_repository import StubFamilyRepository
from app.main import app
from app.services.routine import repository
from app.schemas.movement import BodyPart
from app.services.routine.inputs import to_activities, yesterday_motion
from app.services.routine.rules import apply_rules
from app.services.routine.service import (
    RoutineService,
    _normalize_item_keys,
    attach_videos,
    ensure_health_focus_items,
    load_template,
    template_household,
    load_videos,
    validate,
)

TODAY = date(2026, 9, 16)
USER = "user-1"
HUSBAND = "husband-1"


class FakeQuery:
    def __init__(self, store: "FakeSupabase", table: str) -> None:
        self.store, self.table_name = store, table
        self.filters: list[tuple[str, str, object]] = []
        self.op, self.payload = "select", None
        self._order: list[tuple[str, bool]] = []
        self._limit: int | None = None

    def select(self, *_): return self
    def insert(self, rows): self.op, self.payload = "insert", rows; return self
    def update(self, values): self.op, self.payload = "update", values; return self
    def delete(self): self.op = "delete"; return self
    def eq(self, c, v): self.filters.append(("eq", c, v)); return self
    def lt(self, c, v): self.filters.append(("lt", c, v)); return self
    def in_(self, c, values): self.filters.append(("in", c, list(values))); return self
    def order(self, c, desc=False): self._order.append((c, desc)); return self
    def limit(self, n): self._limit = n; return self

    def _match(self, row) -> bool:
        def ok(op, c, v):
            if op == "eq":
                return str(row.get(c)) == str(v)
            if op == "in":
                return row.get(c) in v
            return str(row.get(c)) < str(v)

        return all(ok(op, c, v) for op, c, v in self.filters)

    def execute(self):
        rows = self.store.tables.setdefault(self.table_name, [])
        if self.op == "insert":
            new = [self.payload] if isinstance(self.payload, dict) else self.payload
            out = []
            for r in new:
                if self.table_name == "daily_routines" and any(
                    (x["user_id"], x["date"], x.get("revision", 1)) == (r["user_id"], r["date"], r.get("revision", 1))
                    for x in rows
                ):
                    raise APIError({"message": "duplicate", "code": "23505"})
                self.store.seq += 1
                row = {"id": f"{self.table_name}-{self.store.seq}", "generated_at": "now",
                       "status": "scheduled", **r} if self.table_name == "routine_items" else \
                      {"id": f"{self.table_name}-{self.store.seq}", "generated_at": "now", **r}
                rows.append(row)
                out.append(row)
            return SimpleNamespace(data=out)
        if self.op == "update":
            hit = [r for r in rows if self._match(r)]
            for r in hit:
                r.update(self.payload)
            return SimpleNamespace(data=hit)
        if self.op == "delete":
            hit = [r for r in rows if self._match(r)]
            if any(r["id"] in self.store.fk_referenced for r in hit):
                raise APIError({"message": "fk", "code": "23503"})
            rows[:] = [r for r in rows if r not in hit]
            return SimpleNamespace(data=hit)
        found = [r for r in rows if self._match(r)]
        for column, desc in reversed(self._order):
            found.sort(key=lambda r: (r.get(column) is None, r.get(column) or 0) if column == "revision"
                       else str(r.get(column) or ""), reverse=desc)
        return SimpleNamespace(data=found[: self._limit] if self._limit else found)


class FakeSupabase:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {}
        self.seq = 0
        self.fk_referenced: set[str] = set()  # 다른 테이블이 FK로 참조 중인 routine_items id

    def table(self, name): return FakeQuery(self, name)

    def rpc(self, name, params):
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=[{"id": 11, "category": params["filter_category"], "content": "근거 문단", "source": "s"}]))


class FakeOpenAI:
    """embeddings.create + chat.completions.create. fail=True면 API 오류를 낸다."""

    def __init__(self, routine_json: str, fail: bool = False) -> None:
        self.embeddings = SimpleNamespace(create=self._embed)
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._chat))
        self.routine_json, self.fail = routine_json, fail
        self.chat_calls: list[dict] = []
        self.tip_fail = False
        self.fail_names: set[str] = set()  # S10: 이 json_schema 이름의 호출만 실패
        self.tip_json = '{"tip": {"text": "허리가 뻐근하면 30분마다 일어나 가볍게 몸을 풀어요", "source_ids": [11, 999]}}'

    async def _embed(self, model, input):
        return SimpleNamespace(data=[SimpleNamespace(embedding=[0.0] * 1536) for _ in input])

    async def _chat(self, **kwargs):
        self.chat_calls.append(kwargs)
        if kwargs["response_format"]["json_schema"]["name"] in self.fail_names:
            raise RuntimeError("category down")
        if kwargs["response_format"]["json_schema"]["name"] == "routine_tip" and not self.fail:
            if self.tip_fail:
                raise RuntimeError("tip down")
            return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=self.tip_json))])
        if self.fail:
            raise RuntimeError("insufficient_quota")
        return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=self.routine_json))])


AI_ROUTINE = {
    "meal": [
        {"item_key": "meal:lunch", "title": "새우 볶음밥", "payload": {"period": "lunch", "reason": "갑각류 단백질"}, "source_ids": [11]},
        {"item_key": "meal:dinner", "title": "두부 조림", "payload": {"period": "dinner", "reason": "식물성 단백질"}, "source_ids": [11, 999]},
    ],
    "household": [{"item_key": "household:laundry", "title": "세탁", "payload": {"owner": "appliance"}, "source_ids": []}],
    "health": [{"item_key": "health:waist", "title": "허리 이완", "payload": {"bodyArea": "허리", "reason": "허리 통증"}, "source_ids": []}],
    "sleep": {"item_key": "sleep:main", "title": "22:30 취침", "payload": {"recommendedBedtime": "22:30"}, "source_ids": [11]},
}


def seed(db: FakeSupabase) -> None:
    db.tables["pregnancy_profiles"] = [{
        "user_id": USER, "due_date": "2027-01-06", "is_first_pregnancy": True, "is_multiple_pregnancy": False,
        "allergies": ["갑각류"], "medical_conditions": [], "medical_note": None,
    }]
    db.tables["daily_conditions"] = [{
        "user_id": USER, "date": TODAY.isoformat(), "nausea": 2, "waist_pain": 4, "pelvis_pain": 2, "leg_pain": 1,
        "wrist_pain": 1, "fatigue": 3, "mood": 4, "sleep_quality": None, "planned_activities": ["laundry"],
    }]


def make_service(db: FakeSupabase, openai: FakeOpenAI) -> RoutineService:
    return RoutineService(db, Settings(llm_api_key="x", _env_file=None), openai)


class ValidateTest(unittest.TestCase):
    def test_removes_excluded_and_unknown_sources(self) -> None:
        constraints = apply_rules({"allergies": ["갑각류"]})
        out = validate(AI_ROUTINE, constraints, {11})
        self.assertEqual([m["title"] for m in out["meal"]], ["두부 조림"])   # 제목 "새우"(갑각류 keywords) 항목 제거
        self.assertEqual(out["meal"][0]["source_ids"], [11])                    # 999 제거
        self.assertEqual(out["sleep"]["source_ids"], [11])

    def test_keeps_item_when_banned_word_only_in_reason(self) -> None:
        # 2026-09-17 실호출: "기름진 음식과 갑각류를 피하면서" 설명 때문에 식단 3개가 모두 지워졌다.
        constraints = apply_rules({"allergies": ["갑각류"], "nausea": 4})
        routine = {"meal": [{"item_key": "meal:lunch", "title": "닭가슴살 샐러드",
                             "payload": {"reason": "기름진 음식과 갑각류를 피하면서 단백질 보충", "nutritionTags": ["단백질"]},
                             "source_ids": []}]}
        self.assertEqual([m["title"] for m in validate(routine, constraints, set())["meal"]], ["닭가슴살 샐러드"])

    def test_purifier_missing_gets_team_confirmed_default(self) -> None:
        """AI가 purifier 항목을 아예 안 줘도 실기기 제어 카드가 사라지지 않게 기본값을 넣는다."""
        out = validate(AI_ROUTINE, apply_rules({}), {11})
        purifier = next(e for e in out["sleep"]["payload"]["environments"] if e["type"] == "purifier")
        self.assertEqual(purifier["value"], "자동")
        self.assertEqual(purifier["options"], ["조용 모드", "자동", "강풍", "끄기"])

    def test_purifier_value_outside_4_options_is_clamped(self) -> None:
        routine = {**AI_ROUTINE, "sleep": {
            **AI_ROUTINE["sleep"],
            "payload": {"environments": [{"type": "purifier", "value": "약하게", "options": ["약하게", "세게"]}]},
        }}
        out = validate(routine, apply_rules({}), set())
        purifier = next(e for e in out["sleep"]["payload"]["environments"] if e["type"] == "purifier")
        self.assertEqual(purifier["value"], "자동")
        self.assertEqual(purifier["options"], ["조용 모드", "자동", "강풍", "끄기"])

    def test_purifier_value_already_valid_is_kept(self) -> None:
        routine = {**AI_ROUTINE, "sleep": {
            **AI_ROUTINE["sleep"],
            "payload": {"environments": [{"type": "purifier", "value": "강풍", "options": []}]},
        }}
        out = validate(routine, apply_rules({}), set())
        purifier = next(e for e in out["sleep"]["payload"]["environments"] if e["type"] == "purifier")
        self.assertEqual(purifier["value"], "강풍")

    def test_purifier_does_not_duplicate_or_drop_other_environments(self) -> None:
        routine = {**AI_ROUTINE, "sleep": {
            **AI_ROUTINE["sleep"],
            "payload": {"environments": [
                {"type": "temperature", "value": "24°C", "options": []},
                {"type": "purifier", "value": "조용 모드", "options": []},
            ]},
        }}
        out = validate(routine, apply_rules({}), set())
        types = [e["type"] for e in out["sleep"]["payload"]["environments"]]
        self.assertEqual(types.count("purifier"), 1)
        self.assertIn("temperature", types)

    def test_fallback_template_purifier_also_normalized(self) -> None:
        """폴백도 validate()를 거치므로 AI 실패한 날에도 실기기 제어 카드가 항상 뜬다."""
        out = validate(load_template(), apply_rules({}), set())
        purifier = next(e for e in out["sleep"]["payload"]["environments"] if e["type"] == "purifier")
        self.assertEqual(purifier["options"], ["조용 모드", "자동", "강풍", "끄기"])

    def test_template_item_keys_follow_key_rules(self) -> None:
        """폴백 템플릿 키도 AI 키 규칙과 같아야 한다(안 맞으면 diff에서 전부 교체로 잡힌다)."""
        from app.services.routine.prompt import HEALTH_KEYS, MEAL_KEYS, SLEEP_KEY
        tpl = load_template()
        self.assertTrue(set(e["item_key"] for e in tpl["meal"]) <= set(MEAL_KEYS))
        self.assertTrue(set(e["item_key"] for e in tpl["health"]) <= set(HEALTH_KEYS))
        self.assertEqual(tpl["sleep"]["item_key"], SLEEP_KEY)
        self.assertTrue(all(e["item_key"].startswith("household:") for e in tpl["household"]))

    def test_meal_key_from_period_and_duplicates_kept(self) -> None:
        """AI가 세 끼에 같은 키를 붙여도 period로 키를 만들어 세 끼 모두 남긴다(09-18 실DB 버그)."""
        routine = {"meal": [
            {"item_key": "meal:breakfast", "payload": {"period": "breakfast"}},
            {"item_key": "meal:breakfast", "payload": {"period": "lunch"}},
            {"item_key": "meal:breakfast", "payload": {"period": "dinner"}},
            {"item_key": "meal:snack", "payload": {"period": "dinner"}},
        ], "health": [{"item_key": "health:waist"}, {"item_key": "health:waist"}]}
        out = _normalize_item_keys(routine)
        self.assertEqual([e["item_key"] for e in out["meal"]],
                         ["meal:breakfast", "meal:lunch", "meal:dinner", "meal:dinner:2"])
        self.assertEqual([e["item_key"] for e in out["health"]], ["health:waist", "health:waist:2"])
        self.assertEqual(len(repository.to_items({**out, "household": [], "sleep": {}})), 6)

    def test_activity_labels_to_codes(self) -> None:
        """S6: DB의 한글 라벨 9종 → 코드, 이미 코드면 그대로, 목록 밖(직접 입력)은 custom + 원문 라벨."""
        self.assertEqual(to_activities(["빨래", "쓰레기 배출", " 정리 정돈 ", "laundry", "강아지 산책", ""]), [
            {"code": "laundry", "label": "빨래"},
            {"code": "trash", "label": "쓰레기 배출"},
            {"code": "tidying", "label": "정리 정돈"},
            {"code": "laundry", "label": "laundry"},
            {"code": "custom", "label": "강아지 산책"},
        ])
        self.assertEqual(to_activities(None), [])

    def test_normalizes_household_item_key(self) -> None:
        out = _normalize_item_keys({"household": [
            {"item_key": "laundry"}, {"item_key": "household:dishes"}, {"item_key": ""},
        ]})
        self.assertEqual([e["item_key"] for e in out["household"]],
                         ["household:laundry", "household:dishes", "household:2"])

    def test_template_matches_schema_shape(self) -> None:
        tpl = load_template()
        self.assertEqual(set(tpl), {"meal", "household", "health", "sleep", "summaries"})  # summaries = 홈 카드 고정 문구(09-22)
        self.assertEqual(len(repository.to_items(tpl)), 4 + 2 + 1 + 1)  # 09-22: 식사 4끼


class YesterdayTest(unittest.TestCase):
    """S8(R5): 전일 루틴 완료 현황·모션 요약을 ① 입력(facts.yesterday)과 request_payload에 넣는다."""

    def setUp(self) -> None:
        self.db = FakeSupabase()
        seed(self.db)

    def run_ai(self) -> tuple[dict, FakeOpenAI]:
        import json
        openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        return asyncio.run(make_service(self.db, openai).generate_today(USER, TODAY)), openai

    def test_yesterday_routine_summary_in_payload_and_prompt(self) -> None:
        y = "2026-09-15"
        self.db.tables["routine_items"] = [
            {"id": "a", "user_id": USER, "date": y, "item_key": "meal:lunch", "status": "completed", "change_kind": None},
            {"id": "b", "user_id": USER, "date": y, "item_key": "health:waist", "status": "scheduled", "change_kind": None},
            {"id": "c", "user_id": USER, "date": y, "item_key": "household:laundry", "status": "skipped", "change_kind": "updated"},
            {"id": "d", "user_id": USER, "date": y, "item_key": "meal:snack", "status": "scheduled", "change_kind": "removed"},
        ]
        saved, openai = self.run_ai()
        self.assertEqual(saved["request_payload"]["yesterday"]["routine"],
                         {"completed": 1, "total": 3, "not_done": ["health:waist", "household:laundry"]})
        self.assertIn("health:waist", openai.chat_calls[0]["messages"][1]["content"])

    def test_no_yesterday_data_is_null_and_routine_still_ai(self) -> None:
        saved, _ = self.run_ai()
        self.assertEqual(saved["source"], "ai")
        self.assertEqual(saved["request_payload"]["yesterday"], {"routine": None, "motion": None})

    def test_motion_summary_numbers_only(self) -> None:
        summary = SimpleNamespace(aggregates=[object()], cumulative_forward_bend_sec=720.0,
                                  top_burdened_body_part=BodyPart.TRUNK, bending_burden_event_count=4,
                                  narratives=["설명 문장은 보내지 않는다"])
        uid = "00000000-0000-0000-0000-000000000001"
        with patch("app.services.routine.inputs.generate_daily_report", return_value=summary) as report:
            motion = yesterday_motion(self.db, uid, TODAY)
        self.assertEqual(report.call_args.args[2], date(2026, 9, 15))  # K5: 어제 날짜(UTC 하루)
        self.assertEqual(motion, {"top_burdened_area": "waist", "bending_burden_events": 4, "forward_bend_min": 12})

    def test_motion_empty_or_failure_is_none(self) -> None:
        uid = "00000000-0000-0000-0000-000000000001"
        empty = SimpleNamespace(aggregates=[], cumulative_forward_bend_sec=0.0,
                                top_burdened_body_part=None, bending_burden_event_count=0, narratives=[])
        with patch("app.services.routine.inputs.generate_daily_report", return_value=empty):
            self.assertIsNone(yesterday_motion(self.db, uid, TODAY))
        with patch("app.services.routine.inputs.generate_daily_report", side_effect=RuntimeError("db down")):
            self.assertIsNone(yesterday_motion(self.db, uid, TODAY))


class WarmupTest(unittest.IsolatedAsyncioTestCase):
    """K1: 기동 시 연결을 미리 열고, 서비스는 프로세스당 1개만 만든다."""

    async def test_warmup_calls_embedding_and_supabase(self) -> None:
        db, openai = FakeSupabase(), FakeOpenAI("")
        service = make_service(db, openai)
        with patch("app.api.v1.routine.get_routine_service", return_value=service):
            await warmup_routine()
        self.assertIn("pregnancy_knowledge", db.tables)  # 조회로 테이블 접근

    async def test_warmup_failure_does_not_raise(self) -> None:
        with patch("app.api.v1.routine.get_routine_service", side_effect=RuntimeError("no env")):
            await warmup_routine()  # 예외가 올라오면 기동이 막힌다

    def test_service_is_created_once_per_process(self) -> None:
        get_routine_service.cache_clear()
        with patch("app.api.v1.routine.RoutineService", side_effect=lambda *a, **k: object()) as factory, \
             patch("app.api.v1.routine.get_supabase_service"), patch("app.api.v1.routine.get_settings"):
            first, second = get_routine_service(), get_routine_service()
        get_routine_service.cache_clear()
        self.assertIs(first, second)
        self.assertEqual(factory.call_count, 1)


class TemplateHouseholdTest(unittest.TestCase):
    """K8: 템플릿 가사 키를 예정 활동 코드로 맞춰, 폴백 뒤 AI 성공 때 가사가 전부 삭제·추가로 잡히지 않게 한다."""

    def test_no_planned_activities_keeps_yaml_template(self) -> None:
        self.assertIsNone(template_household([]))

    def test_keys_follow_activity_codes(self) -> None:
        items = template_household(to_activities(["빨래", "강아지 산책"]))
        self.assertEqual([i["item_key"] for i in items], ["household:laundry", "household:custom"])
        self.assertEqual([i["title"] for i in items], ["빨래", "강아지 산책"])

    def test_fallback_then_ai_keeps_same_household_rows(self) -> None:
        import json
        db = FakeSupabase()
        seed(db)
        asyncio.run(make_service(db, FakeOpenAI("", fail=True)).generate_today(USER, TODAY))  # 폴백
        before = {i["item_key"]: i["id"] for i in db.tables["routine_items"] if i["category"] == "household"}
        self.assertEqual(sorted(before), ["household:laundry"])  # seed의 예정 활동
        saved = asyncio.run(make_service(db, FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))).generate_today(USER, TODAY))
        after = {i["item_key"]: i["id"] for i in db.tables["routine_items"] if i["category"] == "household"}
        self.assertEqual(after["household:laundry"], before["household:laundry"])  # 같은 행 유지
        self.assertNotIn("household:laundry", saved["change_summary"]["removed"])
        self.assertNotIn("household:laundry", saved["change_summary"]["added"])


class StretchingVideoTest(unittest.TestCase):
    """S_stretching_video: 부위별 영상 목록을 health 항목에 붙인다. AI는 URL을 만들지 않는다."""

    VIDEO = {"waist": {"title": "허리 이완 5분", "url": "https://example.com/waist", "duration_min": 5}}

    def test_low_pain_adds_whole_body_recommendation(self) -> None:
        routine = {
            "health": [{
                "item_key": "health:rest",
                "payload": {"bodyArea": "whole"},
            }]
        }
        facts = {key: 2 for key in ("waist_pain", "pelvis_pain", "leg_pain", "wrist_pain")}

        result = ensure_health_focus_items(routine, facts)

        self.assertEqual(result["health"][-1]["item_key"], "health:whole")
        self.assertEqual(result["health"][-1]["payload"]["bodyArea"], "whole")
        self.assertFalse(result["health"][0]["payload"]["isFocus"])
        self.assertTrue(result["health"][-1]["payload"]["isFocus"])

    def test_low_pain_whole_body_recommendation_has_video(self) -> None:
        routine = {"health": [{"item_key": "health:rest", "payload": {"bodyArea": "whole"}}]}
        facts = {key: 2 for key in ("waist_pain", "pelvis_pain", "leg_pain", "wrist_pain")}

        result = attach_videos(ensure_health_focus_items(routine, facts))
        whole = next(item for item in result["health"] if item["item_key"] == "health:whole")

        self.assertEqual(whole["payload"]["video"]["youtube_id"], "InQu8jMT130")

    def test_normal_pain_does_not_add_whole_body_recommendation(self) -> None:
        routine = {"health": [{"item_key": "health:waist", "payload": {}}]}
        facts = {key: 2 for key in ("waist_pain", "pelvis_pain", "leg_pain", "wrist_pain")}
        facts["waist_pain"] = 3

        result = ensure_health_focus_items(routine, facts)

        self.assertEqual([item["item_key"] for item in result["health"]], ["health:waist"])
        self.assertTrue(result["health"][0]["payload"]["isFocus"])

    def test_all_high_pain_parts_are_focus_and_missing_parts_are_added(self) -> None:
        routine = {
            "health": [
                {"item_key": "health:waist", "payload": {"bodyArea": "waist"}},
                {"item_key": "health:whole", "payload": {"bodyArea": "whole"}},
            ]
        }
        facts = {key: 2 for key in ("waist_pain", "pelvis_pain", "leg_pain", "wrist_pain")}
        facts.update({"waist_pain": 4, "pelvis_pain": 3})

        result = ensure_health_focus_items(routine, facts)
        by_part = {item["payload"]["bodyArea"]: item for item in result["health"]}

        self.assertTrue(by_part["waist"]["payload"]["isFocus"])
        self.assertTrue(by_part["pelvis"]["payload"]["isFocus"])
        self.assertFalse(by_part["whole"]["payload"]["isFocus"])

    def test_video_attached_by_body_part(self) -> None:
        routine = {"health": [
            {"item_key": "health:waist", "title": "허리", "payload": {"guide": "천천히"}},
            {"item_key": "health:waist:2", "title": "허리 추가", "payload": {}},
            {"item_key": "health:leg", "title": "다리", "payload": {}},
        ]}
        with patch("app.services.routine.service.load_videos", return_value=self.VIDEO):
            result = attach_videos(routine)
        self.assertEqual(result["health"][0]["payload"]["video"], self.VIDEO["waist"])
        self.assertEqual(result["health"][1]["payload"]["video"], self.VIDEO["waist"])  # 중복 키(:2)도 같은 부위
        self.assertNotIn("video", result["health"][2]["payload"])  # 목록에 없는 부위는 그대로
        self.assertEqual(result["health"][0]["payload"]["guide"], "천천히")

    def test_no_video_field_when_list_empty(self) -> None:
        routine = {"health": [{"item_key": "health:waist", "title": "허리", "payload": {}}]}
        with patch("app.services.routine.service.load_videos", return_value={}):
            self.assertEqual(attach_videos(routine), routine)

    def test_default_file_has_four_active_videos(self) -> None:
        import yaml as _yaml
        from app.services.routine.service import VIDEO_PATH
        parts = (_yaml.safe_load(VIDEO_PATH.read_text(encoding="utf-8")) or {})["videos"]
        self.assertEqual(sorted(parts), ["leg", "pelvis", "rest", "waist", "whole", "wrist"])
        load_videos.cache_clear()
        videos = load_videos()
        self.assertEqual(len(videos), 5)
        self.assertEqual(videos["waist"]["youtube_id"], "33LLeqyVbG0")
        self.assertEqual(videos["whole"]["youtube_id"], "InQu8jMT130")
        self.assertEqual(videos["whole"]["duration"], "25분")


class EditPathTest(unittest.TestCase):
    """S10(R7): 확정 전 루틴이 있을 때 컨디션을 고치면 바뀐 가이드만 다시 만든다(§2.8)."""

    def setUp(self) -> None:
        import json
        self.db = FakeSupabase()
        seed(self.db)
        self.condition = self.db.tables["daily_conditions"][0]
        self.openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        self.service = make_service(self.db, self.openai)

    def generate(self) -> dict:
        self.openai.chat_calls.clear()
        return asyncio.run(self.service.generate_today(USER, TODAY))

    def call_names(self) -> list[str]:
        return sorted(c["response_format"]["json_schema"]["name"] for c in self.openai.chat_calls)

    def items(self) -> dict:
        return {i["item_key"]: i for i in self.db.tables["routine_items"]}

    def test_unchanged_condition_returns_current_without_calls(self) -> None:
        first = self.generate()
        again = self.generate()
        self.assertTrue(again["unchanged"])
        self.assertEqual((again["id"], again["revision"]), (first["id"], 1))
        self.assertEqual(self.openai.chat_calls, [])
        self.assertEqual(len(self.db.tables["daily_routines"]), 1)

    def test_small_change_edits_health_only_and_keeps_other_items(self) -> None:
        """허리 2→3(예정 가사 없음): health만 수정 호출, 식사·수면 항목은 id·완료 기록 그대로."""
        self.condition.update({"waist_pain": 2, "planned_activities": []})
        self.generate()
        before = self.items()
        self.db.tables["routine_items"][0]["status"] = "completed"  # 식단 1개 완료 체크
        self.condition["waist_pain"] = 3
        edited = self.generate()
        self.assertEqual(self.call_names(), ["routine_edit_health", "routine_tip"])
        self.assertEqual(edited["revision"], 2)
        after = self.items()
        for key in ("meal:dinner", "sleep:main"):
            self.assertEqual(after[key]["id"], before[key]["id"])
        self.assertEqual(after["meal:dinner"]["status"], "completed")
        row = self.db.tables["daily_routines"][-1]
        self.assertEqual(row["request_payload"]["generated_categories"], ["health"])
        self.assertEqual(row["change_summary"]["categories"], ["health"])
        self.assertEqual(row["change_summary"]["conditions"], ["waist_pain"])
        prompt = next(c for c in self.openai.chat_calls if c["response_format"]["json_schema"]["name"] == "routine_edit_health")
        self.assertIn('"mode": "TUNE"', prompt["messages"][1]["content"])
        self.assertIn("허리 이완", prompt["messages"][1]["content"])  # 기존 health 루틴 전달

    def test_one_failed_category_keeps_previous_others_update(self) -> None:
        """허리 4→5 + 빨래 예정: health·household 대상. health만 실패 → 나머지 반영, source=ai."""
        first = self.generate()
        self.condition["waist_pain"] = 5
        self.openai.fail_names = {"routine_edit_health"}
        edited = self.generate()
        self.assertEqual(edited["source"], "ai")
        self.assertEqual(edited["response"]["health"], first["response"]["health"])
        row = self.db.tables["daily_routines"][-1]
        self.assertEqual(row["request_payload"]["generated_categories"], ["household"])
        self.assertIn("health", row["request_payload"]["failed_categories"])
        self.assertIn("health", row["error_message"])

    def test_all_targets_failed_is_fallback_prev_then_retry_same_condition(self) -> None:
        self.condition.update({"waist_pain": 2, "planned_activities": []})
        first = self.generate()
        self.condition["waist_pain"] = 3
        self.openai.fail_names = {"routine_edit_health"}
        failed = self.generate()
        self.assertEqual((failed["source"], failed["revision"]), ("fallback_prev", 2))
        self.assertEqual(failed["response"]["meal"], first["response"]["meal"])
        # 재시도: 컨디션은 그대로지만 실패했던 health를 다시 호출한다
        self.openai.fail_names = set()
        retried = self.generate()
        self.assertEqual((retried["source"], retried["revision"]), ("ai", 3))
        self.assertEqual(self.call_names(), ["routine_edit_health", "routine_tip"])

    def test_old_three_meal_routine_regenerates_meal_on_edit(self) -> None:
        """09-22: 4끼 필수 이전 버전(3끼) 루틴은 입덧이 그대로여도 컨디션 수정 때 식사를 다시 만든다."""
        self.condition.update({"waist_pain": 2, "planned_activities": []})
        self.generate()
        self.db.tables["daily_routines"][-1]["prompt_version"] = "2026-09-20.1"  # 예전 버전으로 만든 루틴
        self.condition["waist_pain"] = 3
        self.generate()
        self.assertEqual(self.call_names(), ["routine_edit_health", "routine_edit_meal", "routine_tip"])

    def test_new_version_missing_meal_is_not_regenerated(self) -> None:
        """새 버전인데 끼니가 빠진 경우(알레르기 검증으로 제거)는 매번 다시 만들지 않는다."""
        self.condition.update({"waist_pain": 2, "planned_activities": []})
        self.generate()
        self.condition["waist_pain"] = 3
        self.generate()
        self.assertEqual(self.call_names(), ["routine_edit_health", "routine_tip"])

    def test_nausea_3_to_5_edits_meal_and_health_only(self) -> None:
        self.condition["nausea"] = 3
        self.generate()
        self.condition["nausea"] = 5
        self.generate()
        self.assertEqual(self.call_names(), ["routine_edit_health", "routine_edit_meal", "routine_tip"])

    def test_mixed_direction_is_passed_to_prompt(self) -> None:
        """허리 4→2(호전) + 손목 2→4(악화): health 결정 mixed를 상쇄 없이 전달."""
        self.condition.update({"wrist_pain": 2, "planned_activities": []})
        self.generate()
        self.condition.update({"waist_pain": 2, "wrist_pain": 4})
        self.generate()
        prompt = next(c for c in self.openai.chat_calls if c["response_format"]["json_schema"]["name"] == "routine_edit_health")
        self.assertIn('"direction": "mixed"', prompt["messages"][1]["content"])

    def test_previous_fallback_or_confirmed_uses_full_generation(self) -> None:
        self.openai.fail = True
        self.generate()  # 폴백 루틴
        self.openai.fail = False
        self.generate()  # 같은 컨디션이어도 4종 전체 재생성(재시도)
        self.assertEqual(self.call_names(), ["routine_health", "routine_household", "routine_meal", "routine_sleep", "routine_tip"])
        self.db.tables["daily_routines"][-1]["confirmed_at"] = "2026-09-16T10:00:00+09:00"
        confirmed = self.generate()  # 확정 후 재입력 = 새 루틴(FUC-W-COND-004)
        self.assertEqual(len(self.openai.chat_calls), 5)
        self.assertEqual(confirmed["revision"], 3)


class RoutineServiceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeSupabase()
        seed(self.db)

    def test_ai_success_saves_routine_and_items(self) -> None:
        import json
        service = make_service(self.db, FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False)))
        saved = asyncio.run(service.generate_today(USER, TODAY))
        self.assertEqual(saved["source"], "ai")
        self.assertEqual([m["title"] for m in saved["response"]["meal"]], ["두부 조림"])
        items = self.db.tables["routine_items"]
        self.assertEqual({i["category"] for i in items}, {"meal", "household", "health", "sleep"})
        self.assertTrue(all(i["routine_id"] == saved["id"] for i in items))
        # NFR-014: 요청 기록에는 정해진 키만
        self.assertNotIn("date", saved["request_payload"])
        self.assertEqual(saved["request_payload"]["week"], 24)

    def test_generates_four_categories_in_separate_calls(self) -> None:
        import json
        openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        asyncio.run(make_service(self.db, openai).generate_today(USER, TODAY))
        names = sorted(c["response_format"]["json_schema"]["name"] for c in openai.chat_calls)
        self.assertEqual(names, ["routine_health", "routine_household", "routine_meal", "routine_sleep", "routine_tip"])
        prompts = {c["response_format"]["json_schema"]["name"]: c["messages"][1]["content"] for c in openai.chat_calls}
        # 허리 4 → health의 activity:walk 규칙은 health 호출에만 들어간다
        self.assertIn("activity:walk", prompts["routine_health"])
        self.assertNotIn("activity:walk", prompts["routine_meal"])

    def test_tip_included_with_ai_routine(self) -> None:
        """S7: AI 성공이면 response.tip = {text, source_ids}. 없는 source_id(999)는 제거."""
        import json
        saved = asyncio.run(make_service(self.db, FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))).generate_today(USER, TODAY))
        self.assertEqual(saved["source"], "ai")
        self.assertEqual(saved["response"]["tip"]["source_ids"], [11])
        self.assertIn("허리", saved["response"]["tip"]["text"])
        self.assertNotIn("tip", {i["category"] for i in self.db.tables["routine_items"]})  # 팁은 항목이 아님

    def test_tip_failure_keeps_ai_routine(self) -> None:
        """S7: 팁 호출만 실패하면 tip=None, 루틴은 폴백하지 않고 source=ai."""
        import json
        openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        openai.tip_fail = True
        saved = asyncio.run(make_service(self.db, openai).generate_today(USER, TODAY))
        self.assertEqual((saved["source"], saved["response"]["tip"]), ("ai", None))

    def test_tip_with_banned_word_is_dropped(self) -> None:
        """S7: 알레르기 금지어(갑각류 keywords: 새우)가 든 팁은 None."""
        import json
        openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        openai.tip_json = '{"tip": {"text": "점심에 새우를 곁들여 단백질을 챙겨요", "source_ids": []}}'
        saved = asyncio.run(make_service(self.db, openai).generate_today(USER, TODAY))
        self.assertIsNone(saved["response"]["tip"])

    def test_slow_tip_is_dropped_without_delaying_routine(self) -> None:
        """S7: 루틴이 끝난 뒤 팁을 TIP_GRACE_SEC만 기다린다. 늦으면 tip=None, 루틴은 ai 그대로."""
        import json
        from app.services.routine import service as routine_service
        openai = FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False))
        fast_chat = openai._chat

        async def slow_tip(**kwargs):
            if kwargs["response_format"]["json_schema"]["name"] == "routine_tip":
                await asyncio.sleep(0.5)
            return await fast_chat(**kwargs)

        openai.chat = SimpleNamespace(completions=SimpleNamespace(create=slow_tip))
        with patch.object(routine_service, "TIP_GRACE_SEC", 0.05):
            saved = asyncio.run(make_service(self.db, openai).generate_today(USER, TODAY))
        self.assertEqual((saved["source"], saved["response"]["tip"]), ("ai", None))

    def test_fallback_has_no_tip(self) -> None:
        saved = asyncio.run(make_service(self.db, FakeOpenAI("", fail=True)).generate_today(USER, TODAY))
        self.assertEqual((saved["source"], saved["response"]["tip"]), ("fallback_template", None))

    def test_llm_failure_uses_template_when_no_previous(self) -> None:
        service = make_service(self.db, FakeOpenAI("", fail=True))
        saved = asyncio.run(service.generate_today(USER, TODAY))
        self.assertEqual(saved["source"], "fallback_template")
        self.assertIn("insufficient_quota", saved["error_message"])
        self.assertEqual(len(saved["response"]["meal"]), 4)  # 09-22: 아침·점심·저녁·밤
        # 식단 4 + 기존 건강 안내 1 + 허리 집중 운동 1 + 수면 1 + 예정 가사 1 = 8
        self.assertEqual(len(self.db.tables["routine_items"]), 8)
        focus_items = [
            item for item in saved["response"]["health"]
            if item["payload"]["isFocus"]
        ]
        self.assertEqual(
            [(item["item_key"], item["payload"]["bodyArea"]) for item in focus_items],
            [("health:waist", "waist")],
        )

    def test_llm_failure_uses_previous_routine(self) -> None:
        self.db.tables["daily_routines"] = [{
            "id": "old", "user_id": USER, "date": "2026-09-15", "source": "ai", "response": AI_ROUTINE,
        }]
        service = make_service(self.db, FakeOpenAI("", fail=True))
        saved = asyncio.run(service.generate_today(USER, TODAY))
        self.assertEqual(saved["source"], "fallback_prev")
        # 전일 루틴도 오늘 룰(갑각류 exclude)로 다시 걸러진다
        self.assertEqual([m["title"] for m in saved["response"]["meal"]], ["두부 조림"])
        dates_saved = sorted(r["date"] for r in self.db.tables["daily_routines"])
        self.assertEqual(dates_saved, ["2026-09-15", "2026-09-16"])


class RoutineVersionTest(unittest.TestCase):
    """S3: 같은 날 재생성하면 daily_routines는 새 revision 행, routine_items는 같은 행을 고쳐 쓴다."""

    def setUp(self) -> None:
        self.db = FakeSupabase()
        self.day = TODAY

    def save(self, response):
        return repository.save_routine(
            self.db, USER, self.day, source="ai", response=response, model="m",
            prompt_version="v", request_payload={}, error_message=None,
        )

    def items(self):
        return {i["item_key"]: i for i in self.db.tables["routine_items"]}

    def routine(self, meal_title="두부 조림", with_laundry=True):
        household = [{"item_key": "household:laundry", "title": "세탁", "payload": {}, "source_ids": []}] if with_laundry else []
        return {
            "meal": [{"item_key": "meal:lunch", "title": meal_title, "payload": {}, "source_ids": []},
                     {"item_key": "meal:dinner", "title": "현미밥", "payload": {}, "source_ids": []}],
            "household": household, "health": [],
            "sleep": {"item_key": "sleep:main", "title": "22:30 취침", "payload": {}, "source_ids": []},
        }

    def test_second_generation_adds_revision_and_keeps_item_rows(self) -> None:
        first = self.save(self.routine())
        self.assertEqual((first["revision"], first["change_summary"]), (1, None))
        dinner_id = self.items()["meal:dinner"]["id"]
        self.items()["meal:dinner"].update(status="completed", completed_by="wife", completed_at="t")
        self.items()["meal:lunch"].update(status="completed", completed_by="wife", completed_at="t")

        second = self.save(self.routine(meal_title="닭가슴살", with_laundry=False))
        self.assertEqual(second["revision"], 2)
        self.assertEqual([r["revision"] for r in self.db.tables["daily_routines"]], [1, 2])
        self.assertEqual(second["change_summary"]["updated"], ["meal:lunch"])
        self.assertEqual(second["change_summary"]["removed"], ["household:laundry"])
        items = self.items()
        self.assertEqual(len(items), 3)                        # 중복 없이 현재 상태만
        self.assertEqual(items["meal:dinner"]["id"], dinner_id)  # 같은 행을 고쳐 씀(FK 보호)
        self.assertEqual(items["meal:dinner"]["status"], "completed")  # 그대로인 항목은 완료 유지
        self.assertIsNone(items["meal:dinner"]["change_kind"])
        self.assertEqual(items["meal:lunch"]["status"], "completed")   # 제목이 바뀌어도 같은 키면 완료 유지
        self.assertEqual(items["meal:lunch"]["change_kind"], "updated")
        self.assertTrue(all(i["routine_id"] == second["id"] for i in items.values()))
        self.assertEqual(repository.get_routine(self.db, USER, self.day)["id"], second["id"])

    def test_item_with_menu_feedback_is_kept_as_removed(self) -> None:
        """K9: 메뉴 수락·거절 기록이 있는 항목은 지우지 않는다(cascade로 기록까지 지워지므로)."""
        old_items = [{"item_key": "meal:snack", "title": "간식", "category": "meal", "payload": {}, "source_ids": [], "sort_order": 0}]
        repository.save_routine(
            self.db, USER, TODAY, source="ai", response={"meal": [dict(old_items[0])]}, model="m",
            prompt_version="v", request_payload={}, error_message=None,
        )
        snack = self.db.tables["routine_items"][0]
        self.db.tables["recommendation_feedback"] = [{"id": "f1", "routine_item_id": snack["id"], "kind": "menu_reject"}]
        repository.save_routine(
            self.db, USER, TODAY, source="ai",
            response={"meal": [{"item_key": "meal:lunch", "title": "점심", "payload": {}, "source_ids": []}]},
            model="m", prompt_version="v", request_payload={}, error_message=None,
        )
        kept = [i for i in self.db.tables["routine_items"] if i["item_key"] == "meal:snack"]
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["change_kind"], "removed")
        self.assertEqual(len(self.db.tables["recommendation_feedback"]), 1)  # 기록 보존

    def test_item_without_feedback_is_deleted(self) -> None:
        repository.save_routine(
            self.db, USER, TODAY, source="ai",
            response={"meal": [{"item_key": "meal:snack", "title": "간식", "payload": {}, "source_ids": []}]},
            model="m", prompt_version="v", request_payload={}, error_message=None,
        )
        repository.save_routine(
            self.db, USER, TODAY, source="ai",
            response={"meal": [{"item_key": "meal:lunch", "title": "점심", "payload": {}, "source_ids": []}]},
            model="m", prompt_version="v", request_payload={}, error_message=None,
        )
        self.assertEqual([i["item_key"] for i in self.db.tables["routine_items"]], ["meal:lunch"])

    def test_removed_item_referenced_by_fk_is_marked_not_deleted(self) -> None:
        self.save(self.routine())
        self.db.fk_referenced.add(self.items()["household:laundry"]["id"])  # 가사 요청이 참조 중
        self.save(self.routine(with_laundry=False))
        self.assertEqual(self.items()["household:laundry"]["change_kind"], "removed")

    def test_revision_conflict_retries_once(self) -> None:
        self.save(self.routine())
        stale = iter([0, 1])  # 첫 시도는 낡은 번호(→ revision 1 중복), 두 번째는 최신
        with patch.object(repository, "_current_revision", side_effect=lambda *a: next(stale)):
            second = self.save(self.routine(meal_title="닭가슴살"))
        self.assertEqual(second["revision"], 2)


class RoutineApiTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.db = FakeSupabase()
        seed(self.db)
        self.service = make_service(self.db, FakeOpenAI("", fail=True))
        self.family_repository = StubFamilyRepository()
        self.family_repository.link_for_demo(USER, HUSBAND)
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER)
        app.dependency_overrides[get_routine_service] = lambda: self.service
        app.dependency_overrides[get_family_service] = lambda: FamilyService(self.family_repository)
        self.addAsyncCleanup(self._cleanup)
        patcher = patch("app.utils.dates.today_kst", return_value=TODAY)
        patcher.start()
        self.addCleanup(patcher.stop)

    async def _cleanup(self) -> None:
        app.dependency_overrides.clear()

    async def test_get_404_then_post_then_get(self) -> None:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            self.assertEqual((await client.get("/api/v1/routine/today")).status_code, 404)
            created = await client.post("/api/v1/routine/today")
            self.assertEqual(created.status_code, 201)
            self.assertEqual(created.json()["source"], "fallback_template")
            fetched = await client.get("/api/v1/routine/today")
            self.assertEqual(fetched.status_code, 200)
            self.assertEqual(set(fetched.json()["response"]), {"meal", "household", "health", "sleep", "tip"})

    async def test_response_has_revision_and_regeneration_flags(self) -> None:
        """S4(R2): 첫 생성은 revision 1·is_regeneration false·change_summary null, 재생성은 2·true·변경 요약."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            first = (await client.post("/api/v1/routine/today")).json()
            self.assertEqual((first["revision"], first["is_regeneration"], first["change_summary"]), (1, False, None))
            second = (await client.post("/api/v1/routine/today")).json()
            self.assertEqual((second["revision"], second["is_regeneration"]), (2, True))
            self.assertEqual(set(second["change_summary"]), {"added", "updated", "removed", "unchanged"})
            fetched = (await client.get("/api/v1/routine/today")).json()
        self.assertEqual((fetched["revision"], fetched["is_regeneration"]), (2, True))
        self.assertEqual(fetched["change_summary"], second["change_summary"])

    async def test_post_without_condition_409(self) -> None:
        self.db.tables["daily_conditions"] = []
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/routine/today")
            self.assertEqual(response.status_code, 409)
            self.assertIn("컨디션", response.json()["detail"])
        self.assertEqual(self.family_repository.list_notifications(HUSBAND), [])

    def use_ai(self) -> None:
        import json
        self.service = make_service(self.db, FakeOpenAI(json.dumps(AI_ROUTINE, ensure_ascii=False)))

    async def test_first_generation_notifies_morning_report_then_regeneration_notifies_change(self) -> None:
        """FUC-W-COND-002: 하루 첫 생성 → 오전 리포트 알림. FUC-W-COND-003: 재생성 → 루틴 변경 알림."""
        self.use_ai()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            created = await client.post("/api/v1/routine/today")
            self.assertEqual(created.status_code, 201)
            first = self.family_repository.list_notifications(HUSBAND)
            self.assertEqual([n.type for n in first], ["morning_report"])
            self.assertEqual(first[0].reference_id, created.json()["id"])
            self.assertEqual(first[0].target_date, TODAY)

            # S10: 같은 컨디션으로 다시 부르면 새 버전·알림 없음(결정1)
            same = await client.post("/api/v1/routine/today")
            self.assertEqual(same.json()["revision"], 1)
            self.assertEqual(len(self.family_repository.list_notifications(HUSBAND)), 1)

            self.db.tables["daily_conditions"][0]["waist_pain"] = 5  # 컨디션 수정 → 재생성
            changed = await client.post("/api/v1/routine/today")
            self.assertEqual((changed.status_code, changed.json()["revision"]), (201, 2))
        types = sorted(n.type for n in self.family_repository.list_notifications(HUSBAND))
        self.assertEqual(types, ["condition_changed", "morning_report"])

    async def test_fallback_sends_no_notification(self) -> None:
        """S5: 폴백(source != ai)은 AI 실패 → 앱이 실패 화면·재시도를 띄우므로 남편 알림을 보내지 않는다."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            created = await client.post("/api/v1/routine/today")
        self.assertEqual(created.json()["source"], "fallback_template")
        self.assertEqual(self.family_repository.list_notifications(HUSBAND), [])

    async def test_ai_success_after_fallback_is_morning_report(self) -> None:
        """S5: 폴백 뒤 재시도 성공은 revision 2여도 오늘 첫 AI 루틴 → 오전 리포트(루틴 변경 아님)."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            await client.post("/api/v1/routine/today")            # 1: 폴백
            self.use_ai()
            retried = (await client.post("/api/v1/routine/today")).json()  # 2: AI 성공
        self.assertEqual((retried["revision"], retried["source"]), (2, "ai"))
        self.assertEqual([n.type for n in self.family_repository.list_notifications(HUSBAND)], ["morning_report"])

    async def test_unlinked_wife_generation_sends_nothing(self) -> None:
        app.dependency_overrides[get_family_service] = lambda: FamilyService(StubFamilyRepository())
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            self.assertEqual((await client.post("/api/v1/routine/today")).status_code, 201)
        self.assertEqual(self.family_repository.list_notifications(HUSBAND), [])

    async def test_notification_failure_does_not_break_routine_response(self) -> None:
        class BrokenFamily:
            def notify_routine_ready(self, *args, **kwargs):
                raise RuntimeError("notifications down")

        app.dependency_overrides[get_family_service] = lambda: BrokenFamily()
        self.use_ai()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/routine/today")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(set(response.json()["response"]), {"meal", "household", "health", "sleep", "tip"})


if __name__ == "__main__":
    unittest.main()


class PromptContractTest(unittest.TestCase):
    """09-22: 식사 4끼 필수·수면 환경 type 코드 고정이 스키마와 템플릿에 반영됐는지."""

    def test_sleep_env_type_enum_and_template(self) -> None:
        from app.services.routine.prompt import ROUTINE_SCHEMA, SLEEP_ENV_TYPES, SYSTEM_PROMPT

        env = ROUTINE_SCHEMA["properties"]["sleep"]["properties"]["payload"]["properties"]["environments"]["items"]
        self.assertEqual(env["properties"]["type"]["enum"], list(SLEEP_ENV_TYPES))
        self.assertIn("반드시 4개", SYSTEM_PROMPT)
        tpl = load_template()
        self.assertEqual([m["item_key"] for m in tpl["meal"]][-1], "meal:snack")
        self.assertTrue(all(e["type"] in SLEEP_ENV_TYPES for e in tpl["sleep"]["payload"]["environments"]))
