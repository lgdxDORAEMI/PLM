"""알림(Notification)을 Supabase(notifications)에 실제로 연결한다 — 이전에는
SupabaseFamilyRepository가 add_notification/list_notifications/read_notification을
전부 StubFamilyRepository(fallback)에 위임했다.
"""

import unittest
from datetime import date, datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

from httpx import ASGITransport, AsyncClient

from app.api.v1.family import get_family_service
from app.core.security import CurrentUser, get_current_user
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
        self._order: tuple[str, bool] | None = None
        self._limit: int | None = None
        self._op: str | None = None
        self._payload = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def order(self, column: str, desc: bool = False) -> "FakeTable":
        self._order = (column, desc)
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
        return all(row.get(k) == v for k, v in self._filters.items())

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
        if self._order:
            column, desc = self._order
            rows = sorted(rows, key=lambda r: r[column], reverse=desc)
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


class NotificationApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        self.fake.link()
        self.fake.seed_profile(HUSBAND, "남편")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=WIFE)
        self.addCleanup(app.dependency_overrides.clear)

    async def _create_request(self) -> None:
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/family/household-requests", json=REQUEST_PAYLOAD)
            self.assertEqual(response.status_code, 201)

    async def test_household_request_creates_an_unread_notification_for_husband(self) -> None:
        await self._create_request()

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/notifications")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]["type"], "household_request")
        self.assertIsNone(body[0]["read_at"])

    async def test_other_user_does_not_see_someone_elses_notification(self) -> None:
        await self._create_request()

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=OTHER_HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/notifications")
        self.assertEqual(response.json(), [])

    async def test_reading_marks_read_at_and_persists(self) -> None:
        await self._create_request()

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            listed = await client.get("/api/v1/family/notifications")
            notification_id = listed.json()[0]["notification_id"]

            response = await client.post(f"/api/v1/family/notifications/{notification_id}/read")
            self.assertEqual(response.status_code, 200)
            self.assertIsNotNone(response.json()["read_at"])

            listed_again = await client.get("/api/v1/family/notifications")
        self.assertIsNotNone(listed_again.json()[0]["read_at"])

    async def test_reading_someone_elses_notification_is_404(self) -> None:
        await self._create_request()
        notification_id = self.fake.tables["notifications"][0]["id"]

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=OTHER_HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post(f"/api/v1/family/notifications/{notification_id}/read")
        self.assertEqual(response.status_code, 404)

    async def test_newest_notification_listed_first(self) -> None:
        await self._create_request()
        await self._create_request()
        for index, row in enumerate(self.fake.tables["notifications"]):
            row["created_at"] = f"2026-09-{18 + index:02d}T00:00:00+00:00"

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/notifications")
        created_ats = [item["created_at"] for item in response.json()]
        self.assertEqual(created_ats, sorted(created_ats, reverse=True))

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
            response = await client.get("/api/v1/family/notifications")
        self.assertEqual(response.status_code, 503)


class RoutineReadyNotificationTest(unittest.TestCase):
    """루틴 생성 완료 알림이 notifications 테이블에 실제로 저장되는지(Supabase adapter)."""

    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        self.service = FamilyService(
            SupabaseFamilyRepository(self.fake, fallback=StubFamilyRepository())
        )

    def test_first_of_day_persists_morning_report_for_linked_husband(self) -> None:
        self.fake.link()
        self.service.notify_routine_ready(WIFE, date(2026, 9, 18), "routine-1", first_of_day=True)
        rows = self.fake.tables["notifications"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["recipient_user_id"], HUSBAND)
        self.assertEqual(rows[0]["type"], "morning_report")
        self.assertEqual(rows[0]["reference_id"], "routine-1")
        self.assertEqual(rows[0]["target_date"], "2026-09-18")

    def test_regeneration_persists_condition_changed(self) -> None:
        self.fake.link()
        self.service.notify_routine_ready(WIFE, date(2026, 9, 18), "routine-1", first_of_day=False)
        self.assertEqual(self.fake.tables["notifications"][0]["type"], "condition_changed")
        self.assertEqual(self.fake.tables["notifications"][0]["title"], "아내의 루틴이 변경되었습니다.")

    def test_unlinked_wife_writes_nothing(self) -> None:
        self.service.notify_routine_ready(WIFE, date(2026, 9, 18), "routine-1", first_of_day=True)
        self.assertEqual(self.fake.tables["notifications"], [])


if __name__ == "__main__":
    unittest.main()
