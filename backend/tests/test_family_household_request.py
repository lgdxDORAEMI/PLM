"""가사 요청(Household)을 Supabase(household_requests/household_request_items)에
실제로 연결한다 — 이전에는 SupabaseFamilyRepository가 이 메서드들을 전부
StubFamilyRepository(fallback)에 위임했다.
"""

import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from httpx import ASGITransport, AsyncClient

from app.api.v1.family import get_family_service
from app.core.security import CurrentUser, get_current_user
from app.domains.care.schemas import CompletionActor, ExecutionStatus
from app.domains.care.stub_repository import StubCareRepository
from app.domains.family.schemas import HouseholdRequestStatus
from app.domains.family.service import FamilyService
from app.domains.family.stub_repository import StubFamilyRepository
from app.domains.family.supabase_repository import SupabaseFamilyRepository
from app.main import app

WIFE = "wife-1"
HUSBAND = "husband-1"
OTHER_HUSBAND = "husband-2"
TARGET_DATE = "2026-09-18"


class FakeTable:
    def __init__(self, rows: list[dict], default_factory=None) -> None:
        self._rows = rows
        self._default_factory = default_factory
        self._filters: dict[str, object] = {}
        self._limit: int | None = None
        self._op: str | None = None
        self._payload = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def in_(self, column: str, values: list) -> "FakeTable":
        self._filters[column] = ("in", set(values))
        return self

    def limit(self, size: int) -> "FakeTable":
        self._limit = size
        return self

    def insert(self, payload) -> "FakeTable":
        self._op, self._payload = "insert", payload
        return self

    def update(self, values: dict) -> "FakeTable":
        self._op, self._payload = "update", values
        return self

    def _matches(self, row: dict) -> bool:
        def matches_one(key: str, value) -> bool:
            if isinstance(value, tuple) and value[0] == "in":
                return row.get(key) in value[1]
            return row.get(key) == value

        return all(matches_one(k, v) for k, v in self._filters.items())

    def execute(self) -> SimpleNamespace:
        if self._op == "insert":
            payloads = self._payload if isinstance(self._payload, list) else [self._payload]
            new_rows = []
            for payload in payloads:
                defaults = self._default_factory() if self._default_factory else {}
                new_rows.append({**defaults, **payload})
            self._rows.extend(new_rows)
            return SimpleNamespace(data=new_rows)
        if self._op == "update":
            matched = [row for row in self._rows if self._matches(row)]
            for row in matched:
                row.update(self._payload)
            return SimpleNamespace(data=matched)
        rows = [row for row in self._rows if self._matches(row)]
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


def _household_request_defaults() -> dict:
    return {
        "id": str(uuid4()),
        "status": "unconfirmed",
        "requested_at": datetime.now(timezone.utc).isoformat(),
        "confirmed_at": None,
        "completed_at": None,
    }


def _household_request_item_defaults() -> dict:
    return {"id": str(uuid4()), "status": "unconfirmed"}


def _notification_defaults() -> dict:
    return {
        "id": str(uuid4()),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "read_at": None,
    }


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {
            "partner_links": [],
            "profiles": [],
            "household_requests": [],
            "household_request_items": [],
            "notifications": [],
        }
        self._defaults = {
            "household_requests": _household_request_defaults,
            "household_request_items": _household_request_item_defaults,
            "notifications": _notification_defaults,
        }

    def table(self, name: str) -> FakeTable:
        return FakeTable(self.tables[name], self._defaults.get(name))

    def link(self, wife: str = WIFE, husband: str = HUSBAND) -> None:
        self.tables["partner_links"].append({"wife_user_id": wife, "husband_user_id": husband})

    def seed_profile(self, user_id: str, display_name: str) -> None:
        self.tables["profiles"].append({"user_id": user_id, "display_name": display_name})


def client_for(fake: FakeSupabaseClient) -> AsyncClient:
    app.dependency_overrides[get_family_service] = lambda: FamilyService(
        SupabaseFamilyRepository(fake, fallback=StubFamilyRepository())
    )
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")


REQUEST_PAYLOAD = {
    "target_date": TARGET_DATE,
    "reason": "오늘은 허리 통증이 있는 날이에요.",
    "items": [{"title": "장보기", "helper_info": "우유"}],
}


class HouseholdRequestApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=WIFE)
        self.addCleanup(app.dependency_overrides.clear)

    async def test_creating_request_without_partner_link_is_409(self) -> None:
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
        self.assertEqual(response.status_code, 409)

    async def test_wife_creates_request_husband_confirms_and_completes(self) -> None:
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")

        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
            self.assertEqual(response.status_code, 201)
            body = response.json()
            self.assertEqual(body["status"], HouseholdRequestStatus.UNCONFIRMED)
            self.assertEqual(body["recipient_display_name"], "남편")
            self.assertEqual(len(body["items"]), 1)
            request_id = body["request_id"]
            item_id = body["items"][0]["item_id"]

        # DB에 실제로 저장됐는지 확인 — 응답 재구성이 아니라 영속화 자체를 검증
        self.assertEqual(len(self.fake.tables["household_requests"]), 1)
        self.assertEqual(len(self.fake.tables["household_request_items"]), 1)

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{item_id}/confirm"
            )
            self.assertEqual(response.json()["status"], HouseholdRequestStatus.CONFIRMED)

            response = await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{item_id}/complete"
            )
            self.assertEqual(response.json()["status"], HouseholdRequestStatus.COMPLETED)

        stored = self.fake.tables["household_requests"][0]
        self.assertEqual(stored["status"], "completed")
        self.assertIsNotNone(stored["confirmed_at"])
        self.assertIsNotNone(stored["completed_at"])
        self.assertEqual(self.fake.tables["household_request_items"][0]["status"], "completed")

    async def test_husband_completing_item_marks_routine_item_completed(self) -> None:
        """가사 항목을 남편이 완료하면 홈 '루틴 진행도'가 읽는 routine_items.status도
        같이 completed로 바뀌어야 한다 — 안 그러면 0/4에서 계속 멈춰 있는다."""
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        care_repository = StubCareRepository()
        app.dependency_overrides[get_family_service] = lambda: FamilyService(
            SupabaseFamilyRepository(self.fake, fallback=StubFamilyRepository()),
            care_repository,
        )
        payload = {
            "target_date": TARGET_DATE,
            "reason": "장보기 부탁해요.",
            "items": [{"title": "장보기", "routine_item_id": "routine-meal-1"}],
        }
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://localhost"
        ) as client:
            response = await client.post("/api/v1/family/household-requests", json=payload)
            request_id = response.json()["request_id"]
            item_id = response.json()["items"][0]["item_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://localhost"
        ) as client:
            await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{item_id}/confirm"
            )
            await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{item_id}/complete"
            )

        execution = care_repository._executions[(WIFE, "routine-meal-1")]
        self.assertEqual(execution.status, ExecutionStatus.COMPLETED)
        self.assertEqual(execution.completed_by, CompletionActor.HUSBAND)

    async def test_completed_item_cannot_be_confirmed_again(self) -> None:
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
            request_id = response.json()["request_id"]
            item_id = response.json()["items"][0]["item_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            await client.post(f"/api/v1/family/household-requests/{request_id}/items/{item_id}/confirm")
            await client.post(f"/api/v1/family/household-requests/{request_id}/items/{item_id}/complete")
            response = await client.post(f"/api/v1/family/household-requests/{request_id}/items/{item_id}/confirm")
        self.assertEqual(response.status_code, 409)

    async def test_each_item_confirms_and_completes_independently(self) -> None:
        """남편 가사 요청 화면은 카드(항목)별로 독립된 확인·완료 버튼을 보여준다
        (FUC-H-REQUEST-002 "카드별로 개별 확인·완료 상태 관리") — 항목 하나를
        확인/완료해도 같은 요청의 다른 항목은 그대로여야 한다."""
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        payload = {
            "target_date": TARGET_DATE,
            "reason": "장보기랑 빨래 부탁해요.",
            "items": [{"title": "장보기"}, {"title": "빨래"}],
        }
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=payload)
            request_id = response.json()["request_id"]
            first_item_id = response.json()["items"][0]["item_id"]
            second_item_id = response.json()["items"][1]["item_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{first_item_id}/confirm"
            )
            body = response.json()
            self.assertEqual(body["status"], HouseholdRequestStatus.CONFIRMED)
            statuses = {item["item_id"]: item["status"] for item in body["items"]}
            self.assertEqual(statuses[first_item_id], "confirmed")
            self.assertEqual(statuses[second_item_id], "unconfirmed")

            response = await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{first_item_id}/complete"
            )
            body = response.json()
            # 항목 하나만 완료했을 뿐 나머지 항목이 남아 있으니 요청 전체는 아직 완료가 아니다.
            self.assertEqual(body["status"], HouseholdRequestStatus.CONFIRMED)
            statuses = {item["item_id"]: item["status"] for item in body["items"]}
            self.assertEqual(statuses[first_item_id], "completed")
            self.assertEqual(statuses[second_item_id], "unconfirmed")

    async def test_only_the_owner_pair_can_see_the_request(self) -> None:
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
            request_id = response.json()["request_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=OTHER_HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get(f"/api/v1/family/household-requests/{request_id}")
        self.assertEqual(response.status_code, 403)

    async def test_wife_and_husband_both_see_it_in_their_list(self) -> None:
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        async with client_for(self.fake) as client:
            await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)

        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/household-requests")
        self.assertEqual(len(response.json()), 1)

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/household-requests")
        self.assertEqual(len(response.json()), 1)

    async def test_daily_summary_sums_items_across_same_day_requests(self) -> None:
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        second_payload = {
            "target_date": TARGET_DATE,
            "reason": "빨래도 부탁해요.",
            "items": [{"title": "빨래"}, {"title": "청소"}],
        }

        async with client_for(self.fake) as client:
            response = await client.post(
                "/api/v1/family/household-requests", json=REQUEST_PAYLOAD
            )
            first_id = response.json()["request_id"]
            first_item_id = response.json()["items"][0]["item_id"]
            response = await client.post(
                "/api/v1/family/household-requests", json=second_payload
            )
            second_id = response.json()["request_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            await client.post(
                f"/api/v1/family/household-requests/{first_id}/items/{first_item_id}/confirm"
            )
            await client.post(
                f"/api/v1/family/household-requests/{first_id}/items/{first_item_id}/complete"
            )

            response = await client.get(f"/api/v1/family/household-requests/{first_id}")
            summary = response.json()["daily_summary"]
            self.assertEqual(summary["requested"], 3)
            self.assertEqual(summary["confirmed"], 1)
            self.assertEqual(summary["completed"], 1)

            response = await client.get(f"/api/v1/family/household-requests/{second_id}")
            summary = response.json()["daily_summary"]
            self.assertEqual(summary["requested"], 3)
            self.assertEqual(summary["confirmed"], 1)
            self.assertEqual(summary["completed"], 1)

    async def test_daily_summary_counts_only_the_confirmed_item_in_a_mixed_request(
        self,
    ) -> None:
        """요청 하나 안에 항목이 2개 있고 그중 1개만 확인한 경우, daily_summary의
        confirmed는 1이어야 한다(요청 status 기준으로 항목 2개를 통째로 세면 안 됨 —
        항목별 독립 상태 도입 전에는 이 케이스를 만들 수 없어 놓쳤던 버그)."""
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        payload = {
            "target_date": TARGET_DATE,
            "reason": "장보기랑 빨래 부탁해요.",
            "items": [{"title": "장보기"}, {"title": "빨래"}],
        }
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=payload)
            request_id = response.json()["request_id"]
            first_item_id = response.json()["items"][0]["item_id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post(
                f"/api/v1/family/household-requests/{request_id}/items/{first_item_id}/confirm"
            )
            summary = response.json()["daily_summary"]
            self.assertEqual(summary["requested"], 2)
            self.assertEqual(summary["confirmed"], 1)
            self.assertEqual(summary["completed"], 0)

    async def test_storage_failure_returns_503(self) -> None:
        def raise_connect_error(name: str):
            import httpx

            raise httpx.ConnectError("down")

        app.dependency_overrides[get_family_service] = lambda: FamilyService(
            SupabaseFamilyRepository(
                SimpleNamespace(table=raise_connect_error), fallback=StubFamilyRepository()
            )
        )
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
        self.assertEqual(response.status_code, 503)


if __name__ == "__main__":
    unittest.main()
