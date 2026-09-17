import unittest
from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import patch

import httpx
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from supabase_auth.errors import AuthApiError

from app.api.v1.profile import get_profile_service
from app.core.security import CurrentUser, get_current_user
from app.main import app
from app.schemas.profile import BodyInput, DueDateInput
from app.services.profile_service import ProfileService
from app.utils.dates import pregnancy_age

TODAY = date(2026, 9, 15)


def iso(days_from_today: int) -> str:
    return (TODAY + timedelta(days=days_from_today)).isoformat()


def freeze_today(case: unittest.TestCase) -> None:
    patcher = patch("app.utils.dates.today_kst", return_value=TODAY)
    patcher.start()
    case.addCleanup(patcher.stop)


class FakeSupabaseClient:
    """ProfileService가 쓰는 table() 호출 체인(select/upsert/update)만 흉내 낸다."""

    def __init__(self) -> None:
        self.rows: dict[str, dict] = {}

    def table(self, name: str) -> "FakeQuery":
        assert name == "pregnancy_profiles"
        return FakeQuery(self.rows)


class FakeQuery:
    def __init__(self, rows: dict[str, dict]) -> None:
        self.rows = rows
        self.operation = "select"
        self.payload: dict = {}
        self.user_id = ""

    def select(self, *columns: str) -> "FakeQuery":
        return self

    def upsert(
        self, row: dict, on_conflict: str = "", default_to_null: bool = True
    ) -> "FakeQuery":
        # 실제 Supabase는 default_to_null=True면 요청에 없는 컬럼을 null로 덮어쓴다.
        assert on_conflict == "user_id" and default_to_null is False
        self.operation, self.payload = "upsert", row
        return self

    def update(self, values: dict) -> "FakeQuery":
        self.operation, self.payload = "update", values
        return self

    def eq(self, column: str, value: str) -> "FakeQuery":
        self.user_id = value
        return self

    def limit(self, size: int) -> "FakeQuery":
        return self

    def execute(self) -> SimpleNamespace:
        if self.operation == "upsert":
            user_id = self.payload["user_id"]
            self.rows[user_id] = {**self.rows.get(user_id, {}), **self.payload}
            return SimpleNamespace(data=[self.rows[user_id]])
        row = self.rows.get(self.user_id)
        if self.operation == "update" and row is not None:
            row.update(self.payload)
        return SimpleNamespace(data=[row] if row else [])


class PregnancyAgeTest(unittest.TestCase):
    def test_weeks_and_days(self) -> None:
        for days_until_due, expected in ((280, (0, 0)), (180, (14, 2)), (0, (40, 0)), (300, (0, 0))):
            with self.subTest(days_until_due=days_until_due):
                self.assertEqual(pregnancy_age(TODAY + timedelta(days=days_until_due), TODAY), expected)


class DueDateInputTest(unittest.TestCase):
    def setUp(self) -> None:
        freeze_today(self)

    def test_resolves_due_date(self) -> None:
        for payload, expected_due in (
            ({"due_date": iso(100)}, iso(100)),
            ({"last_period_start": iso(-100)}, iso(180)),
            ({"due_date": iso(180), "last_period_start": iso(-100)}, iso(180)),
            # 병원 진단 출산예정일이 마지막 생리 시작일 + 280일과 달라도 진단값을 그대로 쓴다.
            ({"due_date": iso(174), "last_period_start": iso(-100)}, iso(174)),
            ({"due_date": iso(-14)}, iso(-14)),
            ({"last_period_start": iso(0)}, iso(280)),
            # 상한은 오늘 + 365일이다.
            ({"due_date": iso(365)}, iso(365)),
        ):
            with self.subTest(payload=payload):
                self.assertEqual(DueDateInput.model_validate(payload).due_date.isoformat(), expected_due)

    def test_rejects_invalid(self) -> None:
        for payload in (
            {},
            {"due_date": None, "last_period_start": None},
            {"due_date": iso(-15)},
            {"due_date": iso(366)},
            {"last_period_start": iso(1)},
            {"last_period_start": iso(-295)},
            {"due_date": "2026-02-30"},
            {"due_date": iso(100), "user_id": "someone-else"},
        ):
            with self.subTest(payload=payload):
                with self.assertRaises(ValidationError):
                    DueDateInput.model_validate(payload)


class BodyInputTest(unittest.TestCase):
    def test_accepts_boundaries_and_one_decimal(self) -> None:
        for height, weight in ((100, 30), (250, 200), (165.5, 55.5), ("165", "55")):
            with self.subTest(height=height, weight=weight):
                BodyInput.model_validate({"height_cm": height, "pre_pregnancy_weight_kg": weight})

    def test_rejects_invalid(self) -> None:
        valid = {"height_cm": 165, "pre_pregnancy_weight_kg": 55}
        for field, value in (
            ("height_cm", 99.9),
            ("height_cm", 250.1),
            ("height_cm", 165.55),
            ("height_cm", "abc"),
            ("pre_pregnancy_weight_kg", 29.9),
            ("pre_pregnancy_weight_kg", 200.1),
            ("pre_pregnancy_weight_kg", None),
        ):
            with self.subTest(field=field, value=value):
                with self.assertRaises(ValidationError) as caught:
                    BodyInput.model_validate({**valid, field: value})
                self.assertEqual(caught.exception.errors()[0]["loc"][0], field)
        with self.assertRaises(ValidationError):
            BodyInput.model_validate({"height_cm": 165})


class ProfileApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        freeze_today(self)
        self.supabase = FakeSupabaseClient()
        app.dependency_overrides[get_profile_service] = lambda: ProfileService(self.supabase)
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="user-1")
        self.addCleanup(app.dependency_overrides.clear)

    def client(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_step_by_step_save(self) -> None:
        async with self.client() as client:
            response = await client.get("/api/v1/profile/me")
            self.assertEqual(response.status_code, 404)

            response = await client.put(
                "/api/v1/profile/me/body", json={"height_cm": 165, "pre_pregnancy_weight_kg": 55}
            )
            self.assertEqual(response.status_code, 409)

            response = await client.put(
                "/api/v1/profile/me/due-date", json={"last_period_start": iso(-100)}
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(
                response.json(),
                {
                    "due_date": iso(180),
                    "last_period_start": iso(-100),
                    "height_cm": None,
                    "pre_pregnancy_weight_kg": None,
                    "is_first_pregnancy": None,
                    "is_multiple_pregnancy": None,
                    "allergies": [],
                    "medical_conditions": [],
                    "medical_note": "",
                    "pregnancy_weeks": 14,
                    "pregnancy_days": 2,
                    "completed_step": 1,
                },
            )

            response = await client.put(
                "/api/v1/profile/me/body", json={"height_cm": 165, "pre_pregnancy_weight_kg": 55.5}
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["height_cm"], 165.0)
            self.assertEqual(response.json()["pre_pregnancy_weight_kg"], 55.5)
            self.assertEqual(response.json()["completed_step"], 2)

            # 1단계를 다시 저장해도 2단계 값은 유지되고, 직접 고른 출산예정일이면 생리 시작일은 비워진다.
            response = await client.put("/api/v1/profile/me/due-date", json={"due_date": iso(100)})
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual((body["due_date"], body["last_period_start"]), (iso(100), None))
            self.assertEqual((body["height_cm"], body["completed_step"]), (165.0, 2))

            response = await client.get("/api/v1/profile/me")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), body)

    async def test_steps_3_to_6_require_step_1_first(self) -> None:
        async with self.client() as client:
            response = await client.put(
                "/api/v1/profile/me/pregnancy-history", json={"is_first_pregnancy": True}
            )
            self.assertEqual(response.status_code, 409)

            response = await client.put(
                "/api/v1/profile/me/due-date", json={"due_date": iso(100)}
            )
            self.assertEqual(response.status_code, 200)

            response = await client.put(
                "/api/v1/profile/me/pregnancy-history", json={"is_first_pregnancy": True}
            )
            self.assertEqual(response.status_code, 200)
            self.assertTrue(response.json()["is_first_pregnancy"])
            self.assertEqual(response.json()["completed_step"], 1)  # 2단계가 없어 카운트 정체

            response = await client.put(
                "/api/v1/profile/me/pregnancy-count", json={"is_multiple_pregnancy": False}
            )
            self.assertEqual(response.status_code, 200)
            self.assertFalse(response.json()["is_multiple_pregnancy"])

            response = await client.put(
                "/api/v1/profile/me/allergies", json={"allergies": ["갑각류", "갑각류"]}
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["allergies"], ["갑각류", "갑각류"])

            response = await client.put(
                "/api/v1/profile/me/medical-notes",
                json={"medical_conditions": ["빈혈"], "medical_note": "의사가 참고하라고 함"},
            )
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["medical_conditions"], ["빈혈"])
            self.assertEqual(body["medical_note"], "의사가 참고하라고 함")

            # 신장·체중(2단계)까지 채우면 completed_step이 4까지 정확히 올라간다.
            response = await client.put(
                "/api/v1/profile/me/body", json={"height_cm": 165, "pre_pregnancy_weight_kg": 55}
            )
            self.assertEqual(response.json()["completed_step"], 4)

    async def test_full_six_step_completion_flow(self) -> None:
        """STEP 10: 1~6단계를 순서대로 저장하고 GET이 전체를 그대로 돌려주는지 확인한다
        (W-PROFILE-007 요약 화면이 의존하는 계약)."""
        async with self.client() as client:
            response = await client.put(
                "/api/v1/profile/me/due-date", json={"due_date": iso(100)}
            )
            self.assertEqual(response.status_code, 200)
            response = await client.put(
                "/api/v1/profile/me/body",
                json={"height_cm": 160, "pre_pregnancy_weight_kg": 52},
            )
            self.assertEqual(response.status_code, 200)
            response = await client.put(
                "/api/v1/profile/me/pregnancy-history", json={"is_first_pregnancy": False}
            )
            self.assertEqual(response.status_code, 200)
            response = await client.put(
                "/api/v1/profile/me/pregnancy-count", json={"is_multiple_pregnancy": True}
            )
            self.assertEqual(response.status_code, 200)
            response = await client.put(
                "/api/v1/profile/me/allergies", json={"allergies": ["우유", "계란"]}
            )
            self.assertEqual(response.status_code, 200)
            response = await client.put(
                "/api/v1/profile/me/medical-notes",
                json={"medical_conditions": ["고혈압"], "medical_note": "정기 검진 권유받음"},
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["completed_step"], 4)  # 5~6단계는 카운트 제외(TBD)

            response = await client.get("/api/v1/profile/me")
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body["due_date"], iso(100))
            self.assertEqual(body["height_cm"], 160.0)
            self.assertFalse(body["is_first_pregnancy"])
            self.assertTrue(body["is_multiple_pregnancy"])
            self.assertEqual(body["allergies"], ["우유", "계란"])
            self.assertEqual(body["medical_conditions"], ["고혈압"])
            self.assertEqual(body["medical_note"], "정기 검진 권유받음")

    async def test_husband_cannot_read_wifes_profile(self) -> None:
        """STEP 10: 남편은 아내 Profile 원본을 직접 조회할 수 없다. `/profile/me`는
        항상 호출자 본인의 user_id로만 조회하므로, 아내 데이터를 저장해도 남편으로
        같은 엔드포인트를 부르면 자기 자신의(없는) 프로필만 본다 — 아내 데이터가
        새어 나가지 않는다."""
        async with self.client() as client:
            response = await client.put(
                "/api/v1/profile/me/due-date", json={"due_date": iso(100)}
            )
            self.assertEqual(response.status_code, 200)

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="husband-1")
        async with self.client() as client:
            response = await client.get("/api/v1/profile/me")
            self.assertEqual(response.status_code, 404)  # 아내 데이터가 아니라 "없음"

        # 아내 본인이 다시 조회하면 여전히 자신의 데이터를 정상적으로 본다.
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="user-1")
        async with self.client() as client:
            response = await client.get("/api/v1/profile/me")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["due_date"], iso(100))

    async def test_invalid_payload_is_not_saved(self) -> None:
        async with self.client() as client:
            response = await client.put(
                "/api/v1/profile/me/due-date",
                json={"last_period_start": iso(1)},  # 미래 생리 시작일
            )
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()["detail"][0]["loc"], ["body"])

            response = await client.put(
                "/api/v1/profile/me/body", json={"height_cm": 165.55, "pre_pregnancy_weight_kg": 55}
            )
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()["detail"][0]["loc"], ["body", "height_cm"])
        self.assertEqual(self.supabase.rows, {})

    async def test_storage_failure_returns_503(self) -> None:
        def raise_connect_error(name: str) -> None:
            raise httpx.ConnectError("down")

        failing = SimpleNamespace(table=raise_connect_error)
        app.dependency_overrides[get_profile_service] = lambda: ProfileService(failing)
        with self.assertLogs("app.services.profile_service", "ERROR"):
            async with self.client() as client:
                response = await client.put("/api/v1/profile/me/due-date", json={"due_date": iso(100)})
        self.assertEqual(response.status_code, 503)

    async def test_requires_token(self) -> None:
        del app.dependency_overrides[get_current_user]
        async with self.client() as client:
            for method, path, payload in (
                ("GET", "/api/v1/profile/me", None),
                ("PUT", "/api/v1/profile/me/due-date", {"due_date": iso(100)}),
                ("PUT", "/api/v1/profile/me/body", {"height_cm": 165, "pre_pregnancy_weight_kg": 55}),
            ):
                with self.subTest(path=path):
                    response = await client.request(method, path, json=payload)
                    self.assertEqual(response.status_code, 401)
        self.assertEqual(self.supabase.rows, {})


class CurrentUserTest(unittest.TestCase):
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="token")

    @staticmethod
    def supabase_with(get_user) -> SimpleNamespace:
        return SimpleNamespace(client=SimpleNamespace(auth=SimpleNamespace(get_user=get_user)))

    def test_valid_token(self) -> None:
        supabase = self.supabase_with(lambda jwt: SimpleNamespace(user=SimpleNamespace(id="user-1")))
        self.assertEqual(get_current_user(self.credentials, supabase), CurrentUser(id="user-1"))

    def test_rejected_or_unreachable(self) -> None:
        def raises(error: Exception):
            def get_user(jwt: str):
                raise error

            return get_user

        for get_user, status_code in (
            (raises(AuthApiError("invalid JWT", 401, None)), 401),
            (lambda jwt: None, 401),
            (raises(httpx.ConnectError("down")), 503),
        ):
            with self.subTest(status_code=status_code):
                with self.assertRaises(HTTPException) as caught:
                    get_current_user(self.credentials, self.supabase_with(get_user))
                self.assertEqual(caught.exception.status_code, status_code)
