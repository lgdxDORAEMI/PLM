"""STEP 13: Husband Data & Permission contract test.

- 초대 링크는 1회성(used_at)·만료(expires_at)를 실제로 지킨다.
- partner_links가 유일한 관계 SOURCE다 — husband_* 복제 테이블이 없고, 접근
  권한은 항상 이 테이블로 검증된다.
- 이미 다른 아내와 연동된 남편은 409로 명확히 거절된다(그냥 503이 아님).
- 기능명세서에 없는 연결 해제/거절/자동 거절 엔드포인트가 없다.
"""

import unittest
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

from httpx import ASGITransport, AsyncClient
from postgrest.exceptions import APIError

from app.api.v1.account import get_account_service
from app.core.security import CurrentUser, get_current_user
from app.domains.account.service import AccountService
from app.domains.account.supabase_repository import SupabaseAccountRepository
from app.main import app

WIFE = "wife-1"
WIFE_2 = "wife-2"
HUSBAND = "husband-1"


class FakeTable:
    def __init__(self, rows: list[dict], *, unique_columns: tuple[str, ...] = ()) -> None:
        self._rows = rows
        self._unique_columns = unique_columns
        self._filters: dict[str, object] = {}
        self._limit: int | None = None
        self._op: str | None = None
        self._payload: dict | None = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def limit(self, size: int) -> "FakeTable":
        self._limit = size
        return self

    def insert(self, row: dict) -> "FakeTable":
        self._op, self._payload = "insert", row
        return self

    def update(self, values: dict) -> "FakeTable":
        self._op, self._payload = "update", values
        return self

    def upsert(self, row: dict, on_conflict: str = "", default_to_null: bool = True) -> "FakeTable":
        self._op, self._payload = "upsert", {**row, "__on_conflict__": on_conflict}
        return self

    def _matches(self, row: dict) -> bool:
        return all(row.get(k) == v for k, v in self._filters.items())

    def execute(self) -> SimpleNamespace:
        if self._op == "insert":
            new_row = {"id": str(uuid4()), "used_at": None, **self._payload}
            self._rows.append(new_row)
            return SimpleNamespace(data=[new_row])
        if self._op == "update":
            matched = [row for row in self._rows if self._matches(row)]
            for row in matched:
                row.update(self._payload)
            return SimpleNamespace(data=matched)
        if self._op == "upsert":
            payload = {k: v for k, v in self._payload.items() if k != "__on_conflict__"}
            conflict_keys = self._payload["__on_conflict__"].split(",")
            for other in self._unique_columns:
                if other in conflict_keys:
                    continue
                if any(
                    row.get(other) == payload.get(other) and
                    any(row.get(k) != payload.get(k) for k in conflict_keys)
                    for row in self._rows
                ):
                    raise APIError(
                        {"message": f'duplicate key value violates unique constraint "{other}"', "code": "23505"}
                    )
            existing = next(
                (row for row in self._rows if all(row.get(k) == payload.get(k) for k in conflict_keys)),
                None,
            )
            if existing is not None:
                existing.update(payload)
                return SimpleNamespace(data=[existing])
            new_row = {**payload}
            self._rows.append(new_row)
            return SimpleNamespace(data=[new_row])

        rows = [row for row in self._rows if self._matches(row)]
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {
            "partner_invitations": [],
            "partner_links": [],
            "profiles": [],
            "pregnancy_profiles": [],
        }

    def table(self, name: str) -> FakeTable:
        unique = ("husband_user_id",) if name == "partner_links" else ()
        return FakeTable(self.tables[name], unique_columns=unique)

    def seed_invitation(self, token: str = "tok-1", *, expires_delta=timedelta(hours=72), used_at=None) -> None:
        self.tables["partner_invitations"].append(
            {
                "id": str(uuid4()),
                "wife_user_id": WIFE,
                "token": token,
                "expires_at": (datetime.now(timezone.utc) + expires_delta).isoformat(),
                "used_at": used_at,
            }
        )


def client_for(fake: FakeSupabaseClient) -> AsyncClient:
    app.dependency_overrides[get_account_service] = lambda: AccountService(
        SupabaseAccountRepository(fake)
    )
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")


class InvitationLifecycleTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=WIFE)
        self.addCleanup(app.dependency_overrides.clear)

    async def test_issued_invitation_has_72h_expiry_and_is_unused(self) -> None:
        self.fake.tables["pregnancy_profiles"].append(
            {
                "user_id": WIFE,
                "due_date": "2026-12-20",
                "birth_date": "1993-05-14",
                "height_cm": 160,
                "pre_pregnancy_weight_kg": 55,
                "is_first_pregnancy": True,
                "is_multiple_pregnancy": False,
            }
        )
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations")
        self.assertEqual(response.status_code, 201)
        row = self.fake.tables["partner_invitations"][0]
        self.assertIsNone(row["used_at"])
        expires = datetime.fromisoformat(row["expires_at"])
        created = datetime.now(timezone.utc)
        self.assertLessEqual(expires, created + timedelta(hours=72, seconds=5))
        self.assertGreater(expires, created + timedelta(hours=71))

    async def test_accepting_links_partner_and_marks_token_used_once(self) -> None:
        self.fake.seed_invitation("tok-1")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations/tok-1/accept")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "linked")

        link = self.fake.tables["partner_links"][0]
        self.assertEqual(link, {"wife_user_id": WIFE, "husband_user_id": HUSBAND})  # 원본 데이터 복제 없음
        self.assertTrue(self.fake.tables["partner_invitations"][0]["used_at"])

        husband_profile = next(
            row for row in self.fake.tables["profiles"] if row["user_id"] == HUSBAND
        )
        self.assertEqual(husband_profile["role"], "husband")

    async def test_reusing_used_token_is_conflict_not_success(self) -> None:
        self.fake.seed_invitation("tok-1", used_at=datetime.now(timezone.utc).isoformat())
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations/tok-1/accept")
        self.assertEqual(response.status_code, 409)
        self.assertEqual(self.fake.tables["partner_links"], [])

    async def test_expired_token_is_conflict(self) -> None:
        self.fake.seed_invitation("tok-1", expires_delta=timedelta(hours=-1))
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations/tok-1/accept")
        self.assertEqual(response.status_code, 409)

    async def test_unknown_token_is_not_found(self) -> None:
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations/ghost/accept")
        self.assertEqual(response.status_code, 404)

    async def test_husband_already_linked_to_another_wife_is_rejected_and_token_not_burned(self) -> None:
        """중복 연동 불가 — 실패해도 초대 토큰은 소진되지 않아야 재시도(다른 초대로)가 가능하다."""
        self.fake.tables["partner_links"].append(
            {"wife_user_id": WIFE_2, "husband_user_id": HUSBAND}
        )
        self.fake.seed_invitation("tok-1")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.post("/api/v1/account/partner-invitations/tok-1/accept")
        self.assertEqual(response.status_code, 409)
        # 링크는 실패했지만(이미 다른 아내와 연동), 토큰이 먼저 소모되지는 않았다.
        self.assertIsNone(self.fake.tables["partner_invitations"][0]["used_at"])
        self.assertEqual(len(self.fake.tables["partner_links"]), 1)  # 새 링크는 생기지 않음


class RelationshipAuthorizationTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        self.addCleanup(app.dependency_overrides.clear)

    async def test_bootstrap_destination_depends_on_partner_links_not_a_copy(self) -> None:
        self.fake.tables["profiles"].append({"user_id": HUSBAND, "role": "husband"})
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/account/bootstrap")
        self.assertEqual(response.json()["destination"], "husband_invitation_required")

        self.fake.tables["partner_links"].append({"wife_user_id": WIFE, "husband_user_id": HUSBAND})
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/account/bootstrap")
        self.assertEqual(response.json()["destination"], "husband_calendar")

    async def test_no_unlink_reject_or_auto_reject_endpoints_exist(self) -> None:
        """기능명세서에 없는 연결 해제/거절/자동 거절 기능을 추가하지 않는다."""
        async with client_for(self.fake) as client:
            response = await client.get("/openapi.json")
        paths = response.json()["paths"]
        forbidden_terms = ("unlink", "disconnect", "reject", "decline", "auto-reject", "cancel-link")
        offending = [p for p in paths if any(term in p for term in forbidden_terms)]
        self.assertEqual(offending, [])


if __name__ == "__main__":
    unittest.main()
