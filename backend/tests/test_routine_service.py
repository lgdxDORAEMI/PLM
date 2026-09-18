"""파이프라인 B ①⑥⑦ 단위 테스트. Supabase·OpenAI는 가짜로 대체한다."""

import asyncio
import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from httpx import ASGITransport, AsyncClient
from postgrest.exceptions import APIError

from app.api.v1.routine import get_routine_service
from app.core.config import Settings
from app.core.security import CurrentUser, get_current_user
from app.main import app
from app.services.routine import repository
from app.services.routine.rules import apply_rules
from app.services.routine.service import RoutineService, _normalize_item_keys, load_template, validate

TODAY = date(2026, 9, 16)
USER = "user-1"


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
    def order(self, c, desc=False): self._order.append((c, desc)); return self
    def limit(self, n): self._limit = n; return self

    def _match(self, row) -> bool:
        return all(
            (str(row.get(c)) == str(v)) if op == "eq" else (str(row.get(c)) < str(v))
            for op, c, v in self.filters
        )

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

    async def _embed(self, model, input):
        return SimpleNamespace(data=[SimpleNamespace(embedding=[0.0] * 1536) for _ in input])

    async def _chat(self, **kwargs):
        self.chat_calls.append(kwargs)
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

    def test_normalizes_household_item_key(self) -> None:
        out = _normalize_item_keys({"household": [
            {"item_key": "laundry"}, {"item_key": "household:dishes"}, {"item_key": ""},
        ]})
        self.assertEqual([e["item_key"] for e in out["household"]],
                         ["household:laundry", "household:dishes", "household:2"])

    def test_template_matches_schema_shape(self) -> None:
        tpl = load_template()
        self.assertEqual(set(tpl), {"meal", "household", "health", "sleep"})
        self.assertEqual(len(repository.to_items(tpl)), 3 + 2 + 1 + 1)


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
        self.assertEqual(names, ["routine_health", "routine_household", "routine_meal", "routine_sleep"])
        prompts = {c["response_format"]["json_schema"]["name"]: c["messages"][1]["content"] for c in openai.chat_calls}
        # 허리 4 → health의 activity:walk 규칙은 health 호출에만 들어간다
        self.assertIn("activity:walk", prompts["routine_health"])
        self.assertNotIn("activity:walk", prompts["routine_meal"])

    def test_llm_failure_uses_template_when_no_previous(self) -> None:
        service = make_service(self.db, FakeOpenAI("", fail=True))
        saved = asyncio.run(service.generate_today(USER, TODAY))
        self.assertEqual(saved["source"], "fallback_template")
        self.assertIn("insufficient_quota", saved["error_message"])
        self.assertEqual(len(saved["response"]["meal"]), 3)
        self.assertEqual(len(self.db.tables["routine_items"]), 7)

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
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER)
        app.dependency_overrides[get_routine_service] = lambda: self.service
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
            self.assertEqual(set(fetched.json()["response"]), {"meal", "household", "health", "sleep"})

    async def test_post_without_condition_409(self) -> None:
        self.db.tables["daily_conditions"] = []
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/routine/today")
            self.assertEqual(response.status_code, 409)
            self.assertIn("컨디션", response.json()["detail"])


if __name__ == "__main__":
    unittest.main()
