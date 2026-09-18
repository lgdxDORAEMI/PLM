"""STEP 12: Record(routine_items) / Report(daily_reports) / Calendar contract test.

- Record: 별도 실행 로그 테이블 없이 routine_items.status/completed_by/completed_at를
  직접 갱신하는지.
- Report: 미리보기는 daily_reports에 쓰지 않고(NFR-028), 확정(finalize)만 1개
  행을 만들며 Record+Condition에서 파생하는지.
- Calendar: 별도 테이블 없이 daily_conditions+daily_reports 조합 조회인지.

user_id로 "wife-1" 같은 비-UUID 값을 쓰므로 Movement(posture_events) 조회는
`UUID(user_id)`에서 ValueError가 나 자동으로 빈 값으로 넘어간다(코드가 이미 그렇게
설계됨) — 이 테스트는 Movement Fake를 따로 준비하지 않는다.
"""

import unittest
from datetime import date
from types import SimpleNamespace
from uuid import uuid4

from httpx import ASGITransport, AsyncClient

from app.api.v1.care import _calendar_supabase_client, get_care_service
from app.core.security import CurrentUser, get_current_user
from app.domains.care.service import CareService
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
from app.main import app

TARGET_DATE = date(2026, 9, 18)
USER = "wife-1"


class FakeTable:
    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows
        self._filters: dict[str, object] = {}
        self._gte: dict[str, str] = {}
        self._lt: dict[str, str] = {}
        self._order: str | None = None
        self._limit: int | None = None
        self._op: str | None = None
        self._payload: dict | None = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def gte(self, column: str, value: str) -> "FakeTable":
        self._gte[column] = value
        return self

    def lt(self, column: str, value: str) -> "FakeTable":
        self._lt[column] = value
        return self

    def order(self, column: str) -> "FakeTable":
        self._order = column
        return self

    def limit(self, size: int) -> "FakeTable":
        self._limit = size
        return self

    def update(self, values: dict) -> "FakeTable":
        self._op, self._payload = "update", values
        return self

    def upsert(self, row: dict, on_conflict: str = "", default_to_null: bool = True) -> "FakeTable":
        self._op, self._payload = "upsert", {**row, "__on_conflict__": on_conflict}
        return self

    def _matches(self, row: dict) -> bool:
        for key, value in self._filters.items():
            if row.get(key) != value:
                return False
        for key, value in self._gte.items():
            if row.get(key) is None or row[key] < value:
                return False
        for key, value in self._lt.items():
            if row.get(key) is None or row[key] >= value:
                return False
        return True

    def execute(self) -> SimpleNamespace:
        if self._op == "update":
            matched = [row for row in self._rows if self._matches(row)]
            for row in matched:
                row.update(self._payload)
            return SimpleNamespace(data=matched)
        if self._op == "upsert":
            payload = {k: v for k, v in self._payload.items() if k != "__on_conflict__"}
            conflict_keys = self._payload["__on_conflict__"].split(",")
            existing = next(
                (row for row in self._rows if all(row.get(k) == payload.get(k) for k in conflict_keys)),
                None,
            )
            if existing is not None:
                existing.update(payload)
                return SimpleNamespace(data=[existing])
            new_row = {"id": str(uuid4()), "created_at": "2026-09-18T00:00:00+00:00", **payload}
            self._rows.append(new_row)
            return SimpleNamespace(data=[new_row])

        rows = [row for row in self._rows if self._matches(row)]
        if self._order:
            rows = sorted(rows, key=lambda r: r[self._order])
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {
            "daily_conditions": [],
            "routine_items": [],
            "daily_reports": [],
            "partner_links": [],
            "household_requests": [],
        }

    def table(self, name: str) -> FakeTable:
        return FakeTable(self.tables[name])

    def seed_condition(self, target_date: date = TARGET_DATE, **overrides) -> None:
        row = {
            "user_id": USER,
            "date": target_date.isoformat(),
            "nausea": 2,
            "waist_pain": 2,
            "pelvis_pain": 2,
            "leg_pain": 2,
            "wrist_pain": 2,
            "fatigue": 2,
            "mood": 3,
            "planned_activities": [],
            "updated_at": "2026-09-18T00:00:00+00:00",
        }
        row.update(overrides)
        self.tables["daily_conditions"].append(row)

    def seed_household_request(self, status: str, target_date: date = TARGET_DATE) -> None:
        self.tables["household_requests"].append(
            {"wife_user_id": USER, "date": target_date.isoformat(), "status": status}
        )

    def seed_item(self, item_id: str, category: str, status: str = "scheduled", **overrides) -> None:
        row = {
            "id": item_id,
            "user_id": USER,
            "date": TARGET_DATE.isoformat(),
            "category": category,
            "title": f"{category} 항목",
            "status": status,
            "completed_by": None,
            "completed_at": None,
        }
        row.update(overrides)
        self.tables["routine_items"].append(row)


class RecordApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient()
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(self.client, fallback=StubCareRepository())
        )
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER)
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_completing_item_sets_status_and_actor_on_routine_items(self) -> None:
        self.client.seed_item("item-1", "health")
        async with self.http() as client:
            response = await client.put(
                "/api/v1/care/routine-items/item-1/execution", json={"status": "completed"}
            )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["status"], "completed")
        self.assertEqual(body["completed_by"], "wife")
        self.assertIsNotNone(body["completed_at"])
        # 별도 실행 로그 테이블이 아니라 routine_items 행 자체가 바뀌었는지 확인.
        stored = self.client.tables["routine_items"][0]
        self.assertEqual(stored["status"], "completed")

    async def test_uncompleting_clears_actor_and_timestamp(self) -> None:
        self.client.seed_item(
            "item-1", "health", status="completed", completed_by="wife", completed_at="2026-09-18T00:00:00+00:00"
        )
        async with self.http() as client:
            response = await client.put(
                "/api/v1/care/routine-items/item-1/execution", json={"status": "scheduled"}
            )
        body = response.json()
        self.assertEqual(body["status"], "scheduled")
        self.assertIsNone(body["completed_by"])
        self.assertIsNone(body["completed_at"])

    async def test_unknown_item_returns_404(self) -> None:
        async with self.http() as client:
            response = await client.put(
                "/api/v1/care/routine-items/missing/execution", json={"status": "completed"}
            )
        self.assertEqual(response.status_code, 404)

    async def test_needs_confirmation_is_rejected(self) -> None:
        self.client.seed_item("item-1", "meal")
        async with self.http() as client:
            response = await client.put(
                "/api/v1/care/routine-items/item-1/execution",
                json={"status": "needs_confirmation"},
            )
        self.assertEqual(response.status_code, 409)

    async def test_other_user_cannot_complete_this_users_item(self) -> None:
        self.client.seed_item("item-1", "health")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-2")
        async with self.http() as client:
            response = await client.put(
                "/api/v1/care/routine-items/item-1/execution", json={"status": "completed"}
            )
        self.assertEqual(response.status_code, 404)


class ReportApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient()
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(self.client, fallback=StubCareRepository())
        )
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER)
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_preview_without_condition_is_404(self) -> None:
        async with self.http() as client:
            response = await client.post(
                f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/preview"
            )
        self.assertEqual(response.status_code, 404)

    async def test_preview_does_not_persist(self) -> None:
        """NFR-028: 날짜당 1개만 존재해야 하므로 미리보기는 daily_reports에 쓰지 않는다."""
        self.client.seed_condition()
        self.client.seed_item("item-1", "health", status="completed", completed_by="wife")
        async with self.http() as client:
            response = await client.post(
                f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/preview"
            )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertFalse(body["finalized"])
        self.assertEqual(body["completed_routines"], 1)
        self.assertEqual(self.client.tables["daily_reports"], [])  # 아무것도 안 남았다

    async def test_finalize_persists_exactly_one_row_per_date(self) -> None:
        self.client.seed_condition()
        self.client.seed_item("item-1", "meal", status="completed", completed_by="wife")
        self.client.seed_item("item-2", "household", status="completed", completed_by="appliance")
        async with self.http() as client:
            response = await client.post(
                f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/finalize"
            )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["finalized"])
        self.assertEqual(body["completed_routines"], 2)
        self.assertEqual(body["appliance_executions"], 1)
        self.assertEqual(len(self.client.tables["daily_reports"]), 1)

        # 재확정해도 같은 날짜에 행이 하나만 유지된다(덮어쓰기, 중복 생성 아님).
        async with self.http() as client:
            await client.post(f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/finalize")
        self.assertEqual(len(self.client.tables["daily_reports"]), 1)

    async def test_get_report_after_finalize(self) -> None:
        self.client.seed_condition()
        async with self.http() as client:
            await client.post(f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/finalize")
            response = await client.get(f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["finalized"])

    async def test_get_report_before_finalize_is_404(self) -> None:
        self.client.seed_condition()
        async with self.http() as client:
            response = await client.get(f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}")
        self.assertEqual(response.status_code, 404)

    async def test_no_household_requests_for_the_date_reports_zero_not_fabricated(self) -> None:
        self.client.seed_condition()
        async with self.http() as client:
            response = await client.post(
                f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/preview"
            )
        self.assertEqual(response.json()["family"], {"requested": 0, "confirmed": 0, "completed": 0})

    async def test_family_summary_counts_household_requests_as_a_funnel(self) -> None:
        """status는 unconfirmed→confirmed→completed로만 전이하므로 confirmed/
        completed는 "그 단계까지 간" 누적 개수다 — 현재 unconfirmed인 것만 빼고
        전부 confirmed에도 잡히고, completed인 것만 completed에 잡힌다."""
        self.client.seed_condition()
        self.client.seed_household_request("unconfirmed")
        self.client.seed_household_request("confirmed")
        self.client.seed_household_request("completed")
        self.client.seed_household_request("completed")
        self.client.seed_household_request("confirmed", target_date=date(2026, 8, 1))  # 다른 날짜, 제외

        async with self.http() as client:
            response = await client.post(
                f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/preview"
            )
        self.assertEqual(
            response.json()["family"], {"requested": 4, "confirmed": 3, "completed": 2}
        )


class CalendarApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient()
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(self.client, fallback=StubCareRepository())
        )
        app.dependency_overrides[_calendar_supabase_client] = lambda: self.client
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER)
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_calendar_combines_conditions_and_finalized_reports_without_new_table(self) -> None:
        self.client.seed_condition(date(2026, 9, 1), mood=5, fatigue=1, nausea=1, waist_pain=1, pelvis_pain=1, leg_pain=1, wrist_pain=1)
        self.client.seed_condition(date(2026, 9, 15), fatigue=5, waist_pain=5, pelvis_pain=5, leg_pain=5, wrist_pain=5, nausea=5)
        self.client.seed_condition(date(2026, 8, 31))  # 다른 달, 제외돼야 함

        async with self.http() as client:
            # 9/15만 확정 리포트를 만든다.
            await client.post("/api/v1/care/daily-reports/2026-09-15/finalize")
            response = await client.get("/api/v1/care/calendar/2026-09")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        days = {day["target_date"]: day for day in body["days"]}
        self.assertEqual(set(days.keys()), {"2026-09-01", "2026-09-15"})  # 8월 제외

        self.assertEqual(days["2026-09-01"]["condition_index"], "good")
        self.assertFalse(days["2026-09-01"]["has_report"])

        self.assertEqual(days["2026-09-15"]["condition_index"], "hard")
        self.assertTrue(days["2026-09-15"]["has_report"])
        self.assertTrue(days["2026-09-15"]["report_finalized"])

    async def test_linked_husband_sees_wifes_calendar_not_his_own_empty_one(self) -> None:
        """B-CAL-001(Husband, 읽기 전용): partner_links로 연동된 남편은 자기
        자신이 아니라 아내의 캘린더를 봐야 한다."""
        self.client.seed_condition(date(2026, 9, 1))
        self.client.tables["partner_links"].append(
            {"husband_user_id": "husband-1", "wife_user_id": USER}
        )

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="husband-1")
        async with self.http() as client:
            response = await client.get("/api/v1/care/calendar/2026-09")

        self.assertEqual(response.status_code, 200)
        self.assertEqual({d["target_date"] for d in response.json()["days"]}, {"2026-09-01"})

    async def test_unlinked_husband_sees_his_own_empty_calendar_not_wifes(self) -> None:
        """연동이 없으면 본인 id 그대로 조회한다 — 아내 데이터가 새지 않는다."""
        self.client.seed_condition(date(2026, 9, 1))  # 아내(USER) 소유, 연동 없음

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="husband-1")
        async with self.http() as client:
            response = await client.get("/api/v1/care/calendar/2026-09")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["days"], [])


if __name__ == "__main__":
    unittest.main()
