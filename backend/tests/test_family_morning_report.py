"""STEP 12: 남편 오전 리포트(FUC-H-REPORT-001)는 family authorization + projection
방식이어야 한다 — partner_links로 연동을 확인하고 아내 소유 테이블을 그 자리에서
읽어 요약만 내려주며, 아내 데이터를 별도로 복사 저장하지 않는다.
"""

import unittest
from types import SimpleNamespace

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
    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows
        self._filters: dict[str, object] = {}
        self._order: str | None = None
        self._limit: int | None = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def order(self, column: str) -> "FakeTable":
        self._order = column
        return self

    def limit(self, size: int) -> "FakeTable":
        self._limit = size
        return self

    def execute(self) -> SimpleNamespace:
        rows = [
            row
            for row in self._rows
            if all(row.get(k) == v for k, v in self._filters.items())
        ]
        if self._order:
            rows = sorted(rows, key=lambda r: r[self._order])
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {
            "partner_links": [],
            "pregnancy_profiles": [],
            "daily_conditions": [],
            "routine_items": [],
        }

    def table(self, name: str) -> FakeTable:
        return FakeTable(self.tables[name])

    def link(self, wife: str = WIFE, husband: str = HUSBAND) -> None:
        self.tables["partner_links"].append({"wife_user_id": wife, "husband_user_id": husband})

    def seed_profile(self, due_date: str = "2026-12-20") -> None:
        self.tables["pregnancy_profiles"].append({"user_id": WIFE, "due_date": due_date})

    def seed_condition(self, **overrides) -> None:
        row = {
            "user_id": WIFE,
            "date": TARGET_DATE,
            "nausea": 2,
            "waist_pain": 2,
            "pelvis_pain": 2,
            "leg_pain": 2,
            "wrist_pain": 2,
            "fatigue": 2,
            "mood": 3,
            "planned_activities": ["장보기"],
        }
        row.update(overrides)
        self.tables["daily_conditions"].append(row)

    def seed_item(
        self, category: str, title: str, sort_order: int = 0, *, change_kind: str | None = None
    ) -> None:
        self.tables["routine_items"].append(
            {
                "user_id": WIFE,
                "date": TARGET_DATE,
                "category": category,
                "title": title,
                "sort_order": sort_order,
                "change_kind": change_kind,
            }
        )


class MorningReportTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient()
        app.dependency_overrides[get_family_service] = lambda: FamilyService(
            SupabaseFamilyRepository(self.client, fallback=StubFamilyRepository())
        )
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=HUSBAND)
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_unlinked_husband_is_forbidden_not_leaked_as_not_found(self) -> None:
        """연동 자체가 없으면 403 — 아내 데이터가 있는지 없는지조차 드러내지 않는다."""
        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        self.assertEqual(response.status_code, 403)

    async def test_linked_husband_gets_projection_without_raw_scores(self) -> None:
        self.client.link()
        self.client.seed_profile()
        self.client.seed_condition(fatigue=5, waist_pain=5, mood=1)  # mood는 요약 대상 아님
        self.client.seed_item("meal", "현미밥과 나물", sort_order=0)
        self.client.seed_item("household", "빨래", sort_order=0)

        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        self.assertEqual(response.status_code, 200)
        body = response.json()

        self.assertEqual(body["planned_activities"], ["장보기"])
        self.assertIn("피로감 높음", body["condition_summary"])
        self.assertIn("허리 통증 높음", body["condition_summary"])
        # 원본 점수(정수)는 어디에도 노출되지 않는다.
        self.assertNotIn(5, body["condition_summary"])
        self.assertEqual(body["guide_summaries"]["meal"], "현미밥과 나물")
        self.assertEqual(body["guide_summaries"]["household"], "빨래")

    async def test_removed_items_are_excluded_from_guide_summaries(self) -> None:
        """재생성으로 빠졌지만 FK 때문에 삭제되지 못하고 change_kind='removed'로만
        남은 항목은 더 이상 오늘 루틴이 아니므로 요약에 나오면 안 된다."""
        self.client.link()
        self.client.seed_profile()
        self.client.seed_condition()
        self.client.seed_item("meal", "삭제된 메뉴", sort_order=0, change_kind="removed")
        self.client.seed_item("meal", "현재 메뉴", sort_order=1)

        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["guide_summaries"]["meal"], "현재 메뉴")

    async def test_other_husband_cannot_see_this_wifes_report(self) -> None:
        """다른 남편은 연동돼 있지 않으므로 이 아내의 데이터를 볼 수 없다(부부 단위 격리)."""
        self.client.link(wife=WIFE, husband=HUSBAND)
        self.client.seed_profile()
        self.client.seed_condition()

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=OTHER_HUSBAND)
        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        self.assertEqual(response.status_code, 403)

    async def test_no_condition_for_date_is_404(self) -> None:
        self.client.link()
        self.client.seed_profile()
        # 컨디션 미입력
        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        self.assertEqual(response.status_code, 404)

    async def test_response_never_contains_profile_or_chat_fields(self) -> None:
        """DOMAIN_OWNERSHIP.md 원칙: 프로필 원본·AI 대화 원문은 Family 응답에 없다."""
        self.client.link()
        self.client.seed_profile()
        self.client.seed_condition()
        async with self.http() as client:
            response = await client.get(f"/api/v1/family/morning-reports/{TARGET_DATE}")
        body = response.json()
        self.assertEqual(
            set(body.keys()),
            {"target_date", "pregnancy_week", "condition_summary", "planned_activities", "guide_summaries"},
        )


if __name__ == "__main__":
    unittest.main()
