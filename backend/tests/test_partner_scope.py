"""공유 화면(B-CAL-001, B-MOTION-001) 공통 규칙: 남편은 partner_links로 연동된 아내의
데이터를, 그 외에는 본인 데이터를 본다."""

import unittest
from types import SimpleNamespace

import httpx
from fastapi import HTTPException

from app.api.v1.partner_scope import resolve_data_owner

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
        client = FakeClient([{"husband_user_id": HUSBAND, "wife_user_id": WIFE}])
        self.assertEqual(resolve_data_owner(HUSBAND, client), WIFE)

    def test_wife_and_unlinked_user_keep_their_own_id(self) -> None:
        client = FakeClient([{"husband_user_id": HUSBAND, "wife_user_id": WIFE}])
        self.assertEqual(resolve_data_owner(WIFE, client), WIFE)
        self.assertEqual(resolve_data_owner("stranger", client), "stranger")

    def test_storage_failure_is_503_not_a_silent_fallback(self) -> None:
        with self.assertRaises(HTTPException) as ctx:
            resolve_data_owner(HUSBAND, FakeClient(fail=True))
        self.assertEqual(ctx.exception.status_code, 503)


if __name__ == "__main__":
    unittest.main()
