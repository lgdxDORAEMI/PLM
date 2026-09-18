"""파이프라인 B ①⑥⑦ 단위 테스트. Supabase·OpenAI는 가짜로 대체한다."""

import asyncio
import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from httpx import ASGITransport, AsyncClient

from app.api.v1.family import get_family_service
from app.api.v1.routine import get_routine_service
from app.core.config import Settings
from app.core.security import CurrentUser, get_current_user
from app.domains.family.service import FamilyService
from app.domains.family.stub_repository import StubFamilyRepository
from app.main import app
from app.services.routine import repository
from app.services.routine.rules import apply_rules
from app.services.routine.service import RoutineService, load_template, validate

TODAY = date(2026, 9, 16)
USER = "user-1"
HUSBAND = "husband-1"


class FakeQuery:
    def __init__(self, store: "FakeSupabase", table: str) -> None:
        self.store, self.table_name = store, table
        self.filters: list[tuple[str, str, object]] = []
        self.op, self.payload = "select", None
        self._desc = False

    def select(self, *_): return self
    def upsert(self, row, on_conflict=""): self.op, self.payload = "upsert", row; return self
    def insert(self, rows): self.op, self.payload = "insert", rows; return self
    def delete(self): self.op = "delete"; return self
    def eq(self, c, v): self.filters.append(("eq", c, v)); return self
    def lt(self, c, v): self.filters.append(("lt", c, v)); return self
    def order(self, c, desc=False): self._desc = desc; return self
    def limit(self, n): return self

    def _match(self, row) -> bool:
        return all(
            (str(row.get(c)) == str(v)) if op == "eq" else (str(row.get(c)) < str(v))
            for op, c, v in self.filters
        )

    def execute(self):
        rows = self.store.tables.setdefault(self.table_name, [])
        if self.op == "upsert":
            rows[:] = [r for r in rows if not (r["user_id"] == self.payload["user_id"] and r["date"] == self.payload["date"])]
            row = {"id": f"{self.table_name}-{len(rows)+1}", "generated_at": "now", **self.payload}
            rows.append(row)
            return SimpleNamespace(data=[row])
        if self.op == "insert":
            rows.extend(self.payload)
            return SimpleNamespace(data=self.payload)
        if self.op == "delete":
            rows[:] = [r for r in rows if not self._match(r)]
            return SimpleNamespace(data=[])
        found = [r for r in rows if self._match(r)]
        found.sort(key=lambda r: r.get("date", ""), reverse=self._desc)
        return SimpleNamespace(data=found)


class FakeSupabase:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {}

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
            self.assertEqual(set(fetched.json()["response"]), {"meal", "household", "health", "sleep"})

    async def test_post_without_condition_409(self) -> None:
        self.db.tables["daily_conditions"] = []
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/routine/today")
            self.assertEqual(response.status_code, 409)
            self.assertIn("컨디션", response.json()["detail"])
        self.assertEqual(self.family_repository.list_notifications(HUSBAND), [])

    async def test_first_generation_notifies_morning_report_then_regeneration_notifies_change(self) -> None:
        """FUC-W-COND-002: 하루 첫 생성 → 오전 리포트 알림. FUC-W-COND-003: 재생성 → 루틴 변경 알림."""
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            created = await client.post("/api/v1/routine/today")
            self.assertEqual(created.status_code, 201)
            first = self.family_repository.list_notifications(HUSBAND)
            self.assertEqual([n.type for n in first], ["morning_report"])
            self.assertEqual(first[0].reference_id, created.json()["id"])
            self.assertEqual(first[0].target_date, TODAY)

            self.assertEqual((await client.post("/api/v1/routine/today")).status_code, 201)
        types = sorted(n.type for n in self.family_repository.list_notifications(HUSBAND))
        self.assertEqual(types, ["condition_changed", "morning_report"])

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
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/routine/today")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(set(response.json()["response"]), {"meal", "household", "health", "sleep"})


if __name__ == "__main__":
    unittest.main()
