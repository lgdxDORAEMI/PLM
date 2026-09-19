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
            if all(row.get(key) == value for key, value in self._filters.items())
        ]
        if self._order:
            rows = sorted(rows, key=lambda row: row[self._order])
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self, *, routines: list[dict], items: list[dict]) -> None:
        self.routines = routines
        self.items = items

    def table(self, name: str) -> FakeTable:
        if name == "daily_routines":
            return FakeTable(self.routines)
        if name == "routine_items":
            return FakeTable(self.items)
        raise AssertionError(f"unexpected table: {name}")


def meal_item(sort_order: int, title: str, status: str = "scheduled") -> dict:
    return {
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
