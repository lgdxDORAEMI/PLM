"""공유 화면(B-CAL-001, B-MOTION-001) 공통 규칙: 남편은 partner_links로 연동된 아내의
데이터를, 그 외에는 본인 데이터를 본다."""

import unittest
from types import SimpleNamespace

import httpx
from fastapi import HTTPException

from app.api.v1.partner_scope import resolve_data_owner, resolve_shared_data_owner
from app.domains.errors import PARTNER_NOT_SHARED

WIFE = "wife-1"
HUSBAND = "husband-1"


class FakeClient:
    def __init__(self, links: list[dict] | None = None, *, fail: bool = False) -> None:
        self.links = links or []
        self.fail = fail

    def table(self, name: str):
        client = self

        class Q:
            def __init__(self):
                self.filters = {}

            def select(self, *_):
                return self

            def eq(self, c, v):
                self.filters[c] = v
                return self

            def limit(self, _):
                return self

            def execute(self):
                if client.fail:
                    raise httpx.ConnectError("down")
                rows = [r for r in client.links if all(r.get(k) == v for k, v in self.filters.items())]
                return SimpleNamespace(data=rows)

        return Q()


class ResolveDataOwnerTest(unittest.TestCase):
    def test_linked_husband_resolves_to_wife(self) -> None:
        client = FakeClient([{"husband_user_id": HUSBAND, "wife_user_id": WIFE, "shared_at": "2026-09-18T00:00:00+00:00"}])
        self.assertEqual(resolve_data_owner(HUSBAND, client), WIFE)

    def test_wife_and_unlinked_user_keep_their_own_id(self) -> None:
        client = FakeClient([{"husband_user_id": HUSBAND, "wife_user_id": WIFE, "shared_at": "2026-09-18T00:00:00+00:00"}])
        self.assertEqual(resolve_data_owner(WIFE, client), WIFE)
        self.assertEqual(resolve_data_owner("stranger", client), "stranger")

    def test_shared_owner_is_none_until_wife_shares(self) -> None:
        link = {"husband_user_id": HUSBAND, "wife_user_id": WIFE, "shared_at": None}
        self.assertIsNone(resolve_shared_data_owner(HUSBAND, FakeClient([link])))
        link["shared_at"] = "2026-09-29T00:00:00+00:00"
        self.assertEqual(resolve_shared_data_owner(HUSBAND, FakeClient([link])), WIFE)
        self.assertEqual(resolve_shared_data_owner("stranger", FakeClient([link])), "stranger")

    def test_unshared_link_blocks_report_and_homecam_reads(self) -> None:
        """09-29: 초기화 후 아내가 다시 공개하기 전 남편의 리포트·홈캠 조회는 403이다."""
        link = {"husband_user_id": HUSBAND, "wife_user_id": WIFE, "shared_at": None}
        with self.assertRaises(HTTPException) as ctx:
            resolve_data_owner(HUSBAND, FakeClient([link]))
        self.assertEqual(ctx.exception.status_code, 403)
        self.assertEqual(ctx.exception.detail, PARTNER_NOT_SHARED)

    def test_storage_failure_is_503_not_a_silent_fallback(self) -> None:
        with self.assertRaises(HTTPException) as ctx:
            resolve_data_owner(HUSBAND, FakeClient(fail=True))
        self.assertEqual(ctx.exception.status_code, 503)


if __name__ == "__main__":
    unittest.main()
