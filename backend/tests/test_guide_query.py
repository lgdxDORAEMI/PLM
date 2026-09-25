"""STEP 11: Meal/Household/Health/Sleep Guide Query Layer contract test.

routine_items/daily_routines를 흉내 내는 FakeSupabaseClient로, AI를 다시 호출하지
않고 이미 저장된 행만 읽는지, 카테고리 필터·정렬·실행 상태 반영이 맞는지 확인한다.
"""

import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

import httpx
from httpx import ASGITransport, AsyncClient

from app.api.v1.guide import get_guide_service
from app.core.security import CurrentUser, get_current_user
from app.domains.guide.query_service import GuideQueryService
from app.main import app
from app.utils import dates

# /today API는 실행 시점의 KST 오늘로 조회하므로 테스트 데이터도 같은 날짜로 만든다(고정 날짜면 다음 날부터 404).
TARGET_DATE = dates.today_kst()


class FakeTable:
    """select().eq()...().order()?.limit()?.execute() 체인만 흉내 낸다."""

    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows
        self._filters: dict[str, str] = {}
        self._order: str | None = None
        self._limit: int | None = None

    def select(self, *columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def order(self, column: str, *, desc: bool = False) -> "FakeTable":
        self._order = column
        self._descending = desc
        return self

    def limit(self, size: int) -> "FakeTable":
        self._limit = size
        return self

    def execute(self) -> SimpleNamespace:
        rows = [
            row
            for row in self._rows
            if all(row.get(key) == value for key, value in self._filters.items())
        ]
        if self._order:
            rows = sorted(
                rows,
                key=lambda row: row[self._order],
                reverse=getattr(self, "_descending", False),
            )
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(
        self, *, routines: list[dict], items: list[dict],
        videos: list[dict] | None = None, feedback: list[dict] | None = None,
    ) -> None:
        self.routines = routines
        self.items = items
        self.videos = videos or []
        self.feedback = feedback or []

    def table(self, name: str) -> FakeTable:
        if name == "daily_routines":
            return FakeTable(self.routines)
        if name == "routine_items":
            return FakeTable(self.items)
        if name == "health_exercise_videos":
            return FakeTable(self.videos)
        if name == "recommendation_feedback":
            return FakeTable(self.feedback)
        raise AssertionError(f"unexpected table: {name}")


def meal_item(sort_order: int, title: str, status: str = "scheduled") -> dict:
    return {
        "id": f"item-{sort_order}",
        "user_id": "wife-1",
        "date": TARGET_DATE.isoformat(),
        "category": "meal",
        "item_key": f"meal:{sort_order}",
        "title": title,
        "description": None,
        "payload": {"reasonTitle": "혈당 안정"},
        "status": status,
        "completed_by": None,
        "completed_at": None,
        "sort_order": sort_order,
    }


class GuideQueryServiceTest(unittest.TestCase):
    def test_returns_items_ordered_by_sort_order(self) -> None:
        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[meal_item(1, "저녁"), meal_item(0, "점심")],
        )
        service = GuideQueryService(client)
        from app.domains.guide.schemas import RoutineCategory

        guide = service.get_guide("wife-1", TARGET_DATE, RoutineCategory.MEAL)
        self.assertEqual([item.title for item in guide.items], ["점심", "저녁"])

    def test_latest_meal_replacement_overlays_guide_without_changing_item_id(self) -> None:
        from app.domains.guide.schemas import RoutineCategory

        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[meal_item(0, "원래 아침")],
            feedback=[
                {
                    "user_id": "wife-1", "routine_item_id": "item-0",
                    "kind": "meal_replace", "created_at": "2026-09-24T01:00:00Z",
                    "payload": {"title": "첫 대체식", "reason": "첫 이유"},
                },
                {
                    "user_id": "wife-1", "routine_item_id": "item-0",
                    "kind": "meal_replace", "created_at": "2026-09-24T02:00:00Z",
                    "payload": {
                        "title": "바나나 감자 찜", "reason": "속이 편해요",
                        "period": "breakfast", "nutritionTags": ["에너지"],
                    },
                },
            ],
        )

        guide = GuideQueryService(client).get_guide(
            "wife-1", TARGET_DATE, RoutineCategory.MEAL
        )

        self.assertEqual(guide.items[0].item_id, "item-0")
        self.assertEqual(guide.items[0].title, "바나나 감자 찜")
        self.assertEqual(guide.items[0].payload["reason"], "속이 편해요")

    def test_meal_title_is_returned_with_matching_image_asset(self) -> None:
        from app.domains.guide.schemas import RoutineCategory

        item = {
            **meal_item(0, "연어구이와 현미밥"),
            "payload": {"period": "lunch", "reasonTitle": "균형 잡힌 한 끼"},
        }
        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[item],
        )

        guide = GuideQueryService(client).get_guide(
            "wife-1", TARGET_DATE, RoutineCategory.MEAL
        )

        self.assertEqual(
            guide.items[0].payload["imagePath"],
            "lunch/grilled_salmon_brown_rice.jpg",
        )

    def test_excludes_items_removed_by_regeneration(self) -> None:
        """재생성 시 FK(chat_messages 등)가 삭제를 막아 change_kind='removed'로만
        남은 항목은 더 이상 오늘 루틴이 아니므로 응답에서 빠져야 한다."""
        from app.domains.guide.schemas import RoutineCategory

        removed = {**meal_item(0, "삭제된 항목"), "change_kind": "removed"}
        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[removed, meal_item(1, "저녁")],
        )
        service = GuideQueryService(client)

        guide = service.get_guide("wife-1", TARGET_DATE, RoutineCategory.MEAL)
        self.assertEqual([item.title for item in guide.items], ["저녁"])

    def test_no_routine_raises_not_found(self) -> None:
        from app.domains.errors import DomainNotFoundError
        from app.domains.guide.schemas import RoutineCategory

        client = FakeSupabaseClient(routines=[], items=[])
        service = GuideQueryService(client)
        with self.assertRaises(DomainNotFoundError):
            service.get_guide("wife-1", TARGET_DATE, RoutineCategory.MEAL)

    def test_routine_exists_but_category_empty_returns_empty_list_not_error(self) -> None:
        from app.domains.guide.schemas import RoutineCategory

        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[],
        )
        service = GuideQueryService(client)
        guide = service.get_guide("wife-1", TARGET_DATE, RoutineCategory.SLEEP)
        self.assertEqual(guide.items, [])

    def test_health_item_includes_video_from_catalog(self) -> None:
        from app.domains.guide.schemas import RoutineCategory

        item = {
            **meal_item(0, "허리 이완"),
            "category": "health",
            "item_key": "health:waist",
            "payload": {"bodyArea": "허리", "guide": "천천히 움직여요."},
        }
        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[item],
            videos=[{
                "pain_type": "back",
                "routine_part": "waist",
                "title_ko": "임신 중 허리 통증 완화 스트레칭",
                "provider": "Pregnancy and Postpartum TV",
                "youtube_id": "33LLeqyVbG0",
                "duration": None,
                "target": None,
                "is_active": True,
            }],
        )

        guide = GuideQueryService(client).get_guide(
            "wife-1", TARGET_DATE, RoutineCategory.HEALTH
        )

        self.assertEqual(guide.items[0].payload["video"]["youtube_id"], "33LLeqyVbG0")
        self.assertEqual(guide.items[0].payload["guide"], "천천히 움직여요.")


class GuideApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": TARGET_DATE.isoformat(), "id": "r1"}],
            items=[
                meal_item(0, "점심 - 현미밥과 나물"),
                {
                    **meal_item(1, "저녁 - 죽"),
                    "category": "household",
                    "item_key": "household:0",
                    "status": "completed",
                    "completed_by": "wife",
                },
            ],
        )
        app.dependency_overrides[get_guide_service] = lambda: GuideQueryService(self.client)
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1")
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_meal_and_household_are_independent_queries(self) -> None:
        async with self.http() as client:
            response = await client.get("/api/v1/meals/today")
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["category"], "meal")
            self.assertEqual(len(body["items"]), 1)
            self.assertEqual(body["items"][0]["title"], "점심 - 현미밥과 나물")

            response = await client.get("/api/v1/household/today")
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["category"], "household")
            self.assertEqual(body["items"][0]["status"], "completed")
            self.assertEqual(body["items"][0]["completed_by"], "wife")

    async def test_sleep_guide_with_no_items_is_200_empty(self) -> None:
        async with self.http() as client:
            response = await client.get("/api/v1/sleep/today")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["items"], [])

    async def test_no_routine_today_returns_404(self) -> None:
        app.dependency_overrides[get_guide_service] = lambda: GuideQueryService(
            FakeSupabaseClient(routines=[], items=[])
        )
        async with self.http() as client:
            response = await client.get("/api/v1/health/today")
        self.assertEqual(response.status_code, 404)

    async def test_explicit_date_query_param(self) -> None:
        other_date = date(2026, 9, 1)
        client = FakeSupabaseClient(
            routines=[{"user_id": "wife-1", "date": other_date.isoformat(), "id": "r0"}],
            items=[{**meal_item(0, "지난 메뉴"), "date": other_date.isoformat()}],
        )
        app.dependency_overrides[get_guide_service] = lambda: GuideQueryService(client)
        async with self.http() as http_client:
            response = await http_client.get(f"/api/v1/meals/today?date={other_date.isoformat()}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["items"][0]["title"], "지난 메뉴")

    async def test_requires_token(self) -> None:
        del app.dependency_overrides[get_current_user]
        async with self.http() as client:
            for path in (
                "/api/v1/meals/today",
                "/api/v1/household/today",
                "/api/v1/health/today",
                "/api/v1/sleep/today",
            ):
                with self.subTest(path=path):
                    response = await client.get(path)
                    self.assertEqual(response.status_code, 401)

    async def test_other_user_does_not_see_this_users_routine(self) -> None:
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-2")
        async with self.http() as client:
            response = await client.get("/api/v1/meals/today")
        self.assertEqual(response.status_code, 404)

    async def test_storage_failure_returns_503(self) -> None:
        def raise_connect_error(name: str):
            raise httpx.ConnectError("down")

        app.dependency_overrides[get_guide_service] = lambda: GuideQueryService(
            SimpleNamespace(table=raise_connect_error)
        )
        async with self.http() as client:
            response = await client.get("/api/v1/meals/today")
        self.assertEqual(response.status_code, 503)


if __name__ == "__main__":
    unittest.main()


class SleepEnvironmentTypeTest(unittest.TestCase):
    """09-22: 한글 수면 환경 type을 조회 시 코드로 바꾼다(프론트가 전부 조명으로 표시하던 문제)."""

    def test_korean_types_become_codes(self) -> None:
        from app.domains.guide.query_service import _normalize_payload
        from app.domains.guide.schemas import RoutineCategory

        payload = {"environments": [{"type": "조명", "value": "어둡게"}, {"type": "온도", "value": "22도"},
                                    {"type": "humidity", "value": "50%"}, {"type": "공기청정기", "value": "사용 안함"}]}
        out = _normalize_payload(RoutineCategory.SLEEP, payload)
        self.assertEqual([e["type"] for e in out["environments"]], ["light", "temperature", "humidity", "purifier"])
        self.assertIs(_normalize_payload(RoutineCategory.MEAL, payload), payload)  # 수면만 바꾼다
