"""STEP 9: Condition(FUC-W-COND-001, W-TASK-001) 실 연결 Contract Test.

create / read / update / validation / auth / user isolation / KST date boundary를
다룬다. daily_conditions는 이미 존재하는 테이블이라(STEP 0~7 확인) 새 migration은
만들지 않고, FakeSupabaseClient로 upsert/update/select 체인만 흉내 낸다
(tests/test_profile.py의 패턴을 그대로 따름).
"""

import unittest
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import patch

import httpx
from httpx import ASGITransport, AsyncClient

from app.api.v1.care import get_care_service
from app.api.v1.partner_scope import get_partner_scope_client
from app.core.security import CurrentUser, get_current_user
from app.domains.care.service import CareService
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
from app.main import app
from app.services.routine.inputs import ConditionMissingError, collect_facts
from app.utils import dates

VALID_CONDITION = {
    "nausea": 2,
    "waist_pain": 4,
    "pelvis_pain": 2,
    "leg_pain": 1,
    "wrist_pain": 1,
    "fatigue": 4,
    "mood": 3,
}


class FakeSupabaseClient:
    """daily_conditions의 select/upsert/update 체인만 흉내 낸다. PK가
    (user_id, date) 복합키라 eq()를 두 번 받는다."""

    def __init__(self) -> None:
        self.rows: dict[tuple[str, str], dict] = {}

    def table(self, name: str) -> "FakeQuery":
        assert name == "daily_conditions"
        return FakeQuery(self.rows)


class FakeQuery:
    def __init__(self, rows: dict[tuple[str, str], dict]) -> None:
        self.rows = rows
        self.operation = "select"
        self.payload: dict = {}
        self.filters: dict[str, str] = {}

    def select(self, *columns: str) -> "FakeQuery":
        return self

    def upsert(self, row: dict, on_conflict: str = "", default_to_null: bool = True) -> "FakeQuery":
        assert on_conflict == "user_id,date" and default_to_null is False
        self.operation, self.payload = "upsert", row
        return self

    def update(self, values: dict) -> "FakeQuery":
        self.operation, self.payload = "update", values
        return self

    def eq(self, column: str, value: str) -> "FakeQuery":
        self.filters[column] = value
        return self

    def limit(self, size: int) -> "FakeQuery":
        return self

    def execute(self) -> SimpleNamespace:
        if self.operation == "upsert":
            key = (self.payload["user_id"], self.payload["date"])
            self.rows[key] = {**self.rows.get(key, {}), **self.payload}
            return SimpleNamespace(data=[self.rows[key]])
        key = (self.filters.get("user_id"), self.filters.get("date"))
        row = self.rows.get(key)
        if self.operation == "update" and row is not None:
            row.update(self.payload)
        return SimpleNamespace(data=[row] if row else [])


def _empty_partner_links_client() -> SimpleNamespace:
    """resolve_data_owner()가 조회하는 partner_links를 빈 결과로 준다 — 이
    테스트는 아내 본인 조회만 다루고 남편 파트너 스코프는 대상이 아니다."""
    return SimpleNamespace(
        table=lambda name: SimpleNamespace(
            select=lambda *_: SimpleNamespace(
                eq=lambda *_: SimpleNamespace(
                    limit=lambda *_: SimpleNamespace(
                        execute=lambda: SimpleNamespace(data=[])
                    )
                )
            )
        )
    )


def freeze_today(case: unittest.TestCase, today: date) -> None:
    patcher = patch("app.utils.dates.today_kst", return_value=today)
    patcher.start()
    case.addCleanup(patcher.stop)


class ConditionApiTest(unittest.IsolatedAsyncioTestCase):
    TARGET_DATE = date(2026, 9, 18)

    def setUp(self) -> None:
        self.supabase = FakeSupabaseClient()
        self.stub_fallback = StubCareRepository()
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(self.supabase, fallback=self.stub_fallback)
        )
        app.dependency_overrides[get_partner_scope_client] = _empty_partner_links_client
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1")
        self.addCleanup(app.dependency_overrides.clear)

    def client(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    def path(self, target_date: date | None = None) -> str:
        return f"/api/v1/care/conditions/{(target_date or self.TARGET_DATE).isoformat()}"

    # --- create ---

    async def test_create_condition(self) -> None:
        async with self.client() as client:
            response = await client.put(self.path(), json=VALID_CONDITION)
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["write_kind"], "created")
            self.assertEqual(body["changed_fields"], [])
            self.assertEqual(body["planned_activities"], [])
            for field, value in VALID_CONDITION.items():
                self.assertEqual(body[field], value)

    # --- read ---

    async def test_read_missing_condition_returns_404(self) -> None:
        async with self.client() as client:
            response = await client.get(self.path())
            self.assertEqual(response.status_code, 404)

    async def test_read_after_create(self) -> None:
        async with self.client() as client:
            await client.put(self.path(), json=VALID_CONDITION)
            response = await client.get(self.path())
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["mood"], VALID_CONDITION["mood"])
            # 조회는 아무것도 바꾸지 않았으므로 changed_fields는 비어 있어야 한다.
            self.assertEqual(body["changed_fields"], [])

    # --- update ---

    async def test_update_condition_reports_changed_fields(self) -> None:
        async with self.client() as client:
            await client.put(self.path(), json=VALID_CONDITION)
            response = await client.put(
                self.path(), json={**VALID_CONDITION, "fatigue": 5, "mood": 1}
            )
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["write_kind"], "updated")
            self.assertEqual(set(body["changed_fields"]), {"fatigue", "mood"})

    async def test_save_activities_requires_condition_first(self) -> None:
        async with self.client() as client:
            response = await client.put(
                f"{self.path()}/activities", json={"activities": ["장보기"]}
            )
            self.assertEqual(response.status_code, 409)

            await client.put(self.path(), json=VALID_CONDITION)
            response = await client.put(
                f"{self.path()}/activities",
                json={"activities": ["장보기", "빨래", "장보기"]},
            )
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["planned_activities"], ["장보기", "빨래"])  # 중복 제거
            # 점수는 그대로 유지된다(활동 저장이 컨디션 점수를 덮어쓰지 않음).
            self.assertEqual(body["mood"], VALID_CONDITION["mood"])

    # --- validation ---

    async def test_out_of_range_score_is_rejected(self) -> None:
        async with self.client() as client:
            response = await client.put(self.path(), json={**VALID_CONDITION, "mood": 6})
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()["detail"][0]["loc"][-1], "mood")
        self.assertEqual(self.supabase.rows, {})

    async def test_missing_field_is_rejected(self) -> None:
        payload = {k: v for k, v in VALID_CONDITION.items() if k != "mood"}
        async with self.client() as client:
            response = await client.put(self.path(), json=payload)
            self.assertEqual(response.status_code, 422)

    async def test_extra_field_is_rejected(self) -> None:
        async with self.client() as client:
            response = await client.put(self.path(), json={**VALID_CONDITION, "extra": 1})
            self.assertEqual(response.status_code, 422)

    # --- auth ---

    async def test_requires_token(self) -> None:
        del app.dependency_overrides[get_current_user]
        async with self.client() as client:
            for method, path, payload in (
                ("GET", self.path(), None),
                ("PUT", self.path(), VALID_CONDITION),
                ("PUT", f"{self.path()}/activities", {"activities": []}),
            ):
                with self.subTest(path=path):
                    response = await client.request(method, path, json=payload)
                    self.assertEqual(response.status_code, 401)
        self.assertEqual(self.supabase.rows, {})

    # --- user isolation ---

    async def test_users_do_not_see_each_others_conditions(self) -> None:
        async with self.client() as client:
            await client.put(self.path(), json=VALID_CONDITION)

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-2")
        async with self.client() as client:
            response = await client.get(self.path())
            self.assertEqual(response.status_code, 404)

            response = await client.put(self.path(), json={**VALID_CONDITION, "mood": 5})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["write_kind"], "created")  # wife-1과 별개 행

        # wife-1 데이터는 wife-2의 저장으로 바뀌지 않는다.
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1")
        async with self.client() as client:
            response = await client.get(self.path())
            self.assertEqual(response.json()["mood"], VALID_CONDITION["mood"])

    # --- KST date boundary ---

    async def test_kst_date_boundary_near_utc_midnight(self) -> None:
        """UTC 15:30(=KST 00:30, 다음날)에 저장하면 KST 기준 다음 날짜로 저장돼야
        하고, Routine Generator(collect_facts)도 같은 날짜로 조회할 수 있어야 한다."""
        utc_almost_midnight_kst = datetime(2026, 9, 17, 15, 30, tzinfo=timezone.utc)
        with patch("app.utils.dates.datetime") as mock_datetime:
            mock_datetime.now.side_effect = lambda tz=None: (
                utc_almost_midnight_kst.astimezone(tz) if tz else utc_almost_midnight_kst
            )
            today = dates.today_kst()
        self.assertEqual(today, date(2026, 9, 18))  # UTC로는 9/17이지만 KST로는 9/18

        async with self.client() as client:
            response = await client.put(self.path(today), json=VALID_CONDITION)
            self.assertEqual(response.status_code, 200)

        self.assertIn(("wife-1", "2026-09-18"), self.supabase.rows)
        self.assertNotIn(("wife-1", "2026-09-17"), self.supabase.rows)

    async def test_routine_generator_reads_condition_saved_via_api(self) -> None:
        """Routine Generator(app/services/routine/inputs.py, Routine AI)가 이 API로
        저장한 컨디션을 그대로 읽을 수 있어야 한다 — 컬럼명·PK·날짜 형식 호환성."""
        due_date = self.TARGET_DATE - timedelta(days=100)

        class ProfileAndConditionClient:
            def __init__(self, condition_client: FakeSupabaseClient) -> None:
                self._condition_client = condition_client
                self._profile_rows = [{"due_date": due_date.isoformat()}]

            def table(self, name: str):
                if name == "pregnancy_profiles":
                    return SimpleNamespace(
                        select=lambda *_: SimpleNamespace(
                            eq=lambda *_: SimpleNamespace(
                                limit=lambda *_: SimpleNamespace(
                                    execute=lambda: SimpleNamespace(data=self._profile_rows)
                                )
                            )
                        )
                    )
                return self._condition_client.table(name)

        async with self.client() as client:
            response = await client.put(self.path(), json=VALID_CONDITION)
            self.assertEqual(response.status_code, 200)

        combined_client = ProfileAndConditionClient(self.supabase)
        facts = collect_facts(combined_client, "wife-1", self.TARGET_DATE)
        for field, value in VALID_CONDITION.items():
            if field != "mood":
                self.assertEqual(facts[field], value)
        # K3(2026-09-20): sleep_quality는 04_1 컨디션 입력 4종에 없어 Routine 입력에서 뺐다(daily_conditions 컬럼은 유지)
        self.assertNotIn("sleep_quality", facts)
        # 2026-09-22: mood도 회의 결정으로 Routine 입력에서 뺐다(Care 저장 계약·컬럼은 유지)
        self.assertNotIn("mood", facts)

    async def test_routine_generator_raises_when_condition_missing(self) -> None:
        combined_client = SimpleNamespace(
            table=lambda name: (
                SimpleNamespace(
                    select=lambda *_: SimpleNamespace(
                        eq=lambda *_: SimpleNamespace(
                            limit=lambda *_: SimpleNamespace(
                                execute=lambda: SimpleNamespace(
                                    data=[{"due_date": self.TARGET_DATE.isoformat()}]
                                )
                            )
                        )
                    )
                )
                if name == "pregnancy_profiles"
                else self.supabase.table(name)
            )
        )
        with self.assertRaises(ConditionMissingError):
            collect_facts(combined_client, "wife-1", self.TARGET_DATE)

    async def test_storage_failure_returns_503(self) -> None:
        def raise_connect_error(name: str) -> None:
            raise httpx.ConnectError("down")

        failing = SimpleNamespace(table=raise_connect_error)
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(failing, fallback=self.stub_fallback)
        )
        async with self.client() as client:
            response = await client.put(self.path(), json=VALID_CONDITION)
        self.assertEqual(response.status_code, 503)


if __name__ == "__main__":
    unittest.main()
