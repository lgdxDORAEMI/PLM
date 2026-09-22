"""The two presentation sessions stay server-side and local-only."""

import unittest
from types import SimpleNamespace
from unittest.mock import patch

from httpx import ASGITransport, AsyncClient

from app.api.v1.account import get_settings
from app.core.config import Settings
from app.core.security import CurrentUser, get_current_user
from app.domains.account.session_service import issue_account_session
from app.main import app


SETTINGS = Settings(
    supabase_url="https://example.supabase.co",
    supabase_anon_key="public-key",
    plm_wife_email="wife@example.com",
    plm_wife_password="wife-test-password",
    plm_husband_email="husband@example.com",
    plm_husband_password="husband-test-password",
)


class AccountSessionTest(unittest.IsolatedAsyncioTestCase):
    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_uses_isolated_public_key_client(self) -> None:
        session = SimpleNamespace(access_token="access", refresh_token="refresh")
        user = SimpleNamespace(id="wife-id", email="wife@example.com")
        client = SimpleNamespace(
            auth=SimpleNamespace(sign_in_with_password=lambda credentials: SimpleNamespace(session=session, user=user))
        )
        with patch("app.domains.account.session_service.create_client", return_value=client) as create:
            result = issue_account_session(SETTINGS, "wife")
        create.assert_called_once_with(SETTINGS.supabase_url, "public-key")
        self.assertEqual(result["user_id"], "wife-id")
        self.assertEqual(result["refresh_token"], "refresh")

    async def test_default_session_requires_loopback(self) -> None:
        app.dependency_overrides[get_settings] = lambda: SETTINGS
        with patch("app.api.v1.account.issue_account_session") as issue:
            async with AsyncClient(
                transport=ASGITransport(app=app, client=("192.0.2.10", 12345)),
                base_url="http://test",
            ) as client:
                response = await client.post("/api/v1/account/session/default")
        self.assertEqual(response.status_code, 403)
        issue.assert_not_called()

    async def test_switch_requires_configured_source_account(self) -> None:
        app.dependency_overrides[get_settings] = lambda: SETTINGS
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(
            id="other", email="other@example.com"
        )
        with patch("app.api.v1.account.issue_account_session") as issue:
            async with AsyncClient(
                transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
                base_url="http://test",
            ) as client:
                response = await client.post(
                    "/api/v1/account/session/switch", json={"target": "husband"}
                )
        self.assertEqual(response.status_code, 403)
        issue.assert_not_called()

    async def test_switch_issues_target_session_to_configured_account(self) -> None:
        app.dependency_overrides[get_settings] = lambda: SETTINGS
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(
            id="wife-id", email="wife@example.com"
        )
        session = {
            "account": "husband",
            "user_id": "husband-id",
            "access_token": "access",
            "refresh_token": "refresh",
        }
        with patch("app.api.v1.account.issue_account_session", return_value=session) as issue:
            async with AsyncClient(
                transport=ASGITransport(app=app, client=("127.0.0.1", 12345)),
                base_url="http://test",
            ) as client:
                response = await client.post(
                    "/api/v1/account/session/switch", json={"target": "husband"}
                )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.assertEqual(response.json(), session)
        issue.assert_called_once_with(SETTINGS, "husband")
