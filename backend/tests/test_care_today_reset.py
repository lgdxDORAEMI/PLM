"""Today's reset is scoped to the authenticated wife and the KST date."""

import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

import httpx
from httpx import ASGITransport, AsyncClient

from app.api.v1.care import get_care_service
from app.core.security import CurrentUser, get_current_user
from app.domains.care.service import CareService
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
from app.main import app


class FakeResetClient:
    def __init__(self, role: str) -> None:
        self.role = role
        self.calls: list[tuple[str, dict]] = []
        self.fail_rpc = False

    def table(self, name: str):
        assert name == "profiles"
        return self

    def select(self, *_columns: str):
        return self

    def eq(self, _column: str, _value: str):
        return self

    def limit(self, _size: int):
        return self

    def rpc(self, name: str, params: dict):
        self.calls.append((name, params))
        return self

    def execute(self):
        if self.calls:
            if self.fail_rpc:
                raise httpx.ConnectError("storage unavailable")
            return SimpleNamespace(data=None)
        return SimpleNamespace(data=[{"role": self.role}])


class TodayResetApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeResetClient("wife")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1")
        app.dependency_overrides[get_care_service] = lambda: CareService(
            SupabaseCareRepository(self.client, fallback=StubCareRepository())
        )
        patcher = patch("app.api.v1.care.dates.today_kst", return_value=date(2026, 9, 22))
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(app.dependency_overrides.clear)

    async def _request(self):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            return await client.post("/api/v1/care/today/reset")

    async def test_wife_resets_only_her_current_day(self) -> None:
        response = await self._request()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"target_date": "2026-09-22", "reset": True})
        self.assertEqual(
            self.client.calls,
            [("reset_daily_experience", {"p_user_id": "wife-1", "p_target_date": "2026-09-22"})],
        )

    async def test_husband_cannot_reset_wife_data(self) -> None:
        self.client.role = "husband"
        response = await self._request()
        self.assertEqual(response.status_code, 403)
        self.assertEqual(self.client.calls, [])

    async def test_rpc_failure_is_not_reported_as_success(self) -> None:
        self.client.fail_rpc = True
        response = await self._request()
        self.assertEqual(response.status_code, 503)
