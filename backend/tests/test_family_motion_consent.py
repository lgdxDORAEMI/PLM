"""STEP 14: Movement Data Integration contract test.

- 신규 DB 스키마(`motion_consents`)를 실제로 연결하되, 저장 가능한 데이터가
  파생/설정값(동의 여부·ON/OFF)뿐이고 카메라 프레임·영상·landmark가 전혀 없는지
  확인한다.
- 기존 Movement 알고리즘·Protected 스키마(PostureEvent/CalibrationProfileSchema)는
  손대지 않았음을 필드 목록으로 재확인한다(회귀 가드).
- MovementEventRepository 경계(=이미 있는 EventStore Protocol)를 재사용했는지 확인한다.
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
from app.schemas.movement import CalibrationProfileSchema, PostureEvent
from app.services.movement.events import EventStore, InMemoryEventStore, SupabaseEventStore

WIFE = "wife-1"

# 카메라 프레임/영상/landmark로 복원 가능한 데이터를 가리키는 이름들 — 저장 금지 대상.
# (단일 문자 x/y/z는 posture_type처럼 무관한 필드까지 오검출하므로 쓰지 않는다.)
FORBIDDEN_FIELD_HINTS = ("landmark", "frame_data", "video", "image", "world_")


class FakeTable:
    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows
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

    def upsert(self, row: dict, on_conflict: str = "", default_to_null: bool = True) -> "FakeTable":
        self._op, self._payload = "upsert", {**row, "__on_conflict__": on_conflict}
        return self

    def execute(self) -> SimpleNamespace:
        if self._op == "upsert":
            payload = {k: v for k, v in self._payload.items() if k != "__on_conflict__"}
            conflict_keys = self._payload["__on_conflict__"].split(",")
            existing = next(
                (row for row in self._rows if all(row.get(k) == payload.get(k) for k in conflict_keys)),
                None,
            )
            if existing is not None:
                existing.update(payload)
                return SimpleNamespace(data=[existing])
            self._rows.append(payload)
            return SimpleNamespace(data=[payload])
        rows = [row for row in self._rows if all(row.get(k) == v for k, v in self._filters.items())]
        if self._limit is not None:
            rows = rows[: self._limit]
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.tables: dict[str, list[dict]] = {"motion_consents": []}

    def table(self, name: str) -> FakeTable:
        return FakeTable(self.tables[name])


def client_for(fake: FakeSupabaseClient) -> AsyncClient:
    app.dependency_overrides[get_family_service] = lambda: FamilyService(
        SupabaseFamilyRepository(fake, fallback=StubFamilyRepository())
    )
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")


class MotionConsentApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.fake = FakeSupabaseClient()
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=WIFE)
        self.addCleanup(app.dependency_overrides.clear)

    async def test_no_row_defaults_to_not_consented(self) -> None:
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/motion/privacy")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertFalse(body["consent_granted"])
        self.assertFalse(body["collection_enabled"])

    async def test_collection_requires_consent_first(self) -> None:
        async with client_for(self.fake) as client:
            response = await client.put("/api/v1/family/motion/collection", json={"enabled": True})
            self.assertEqual(response.status_code, 409)

            await client.put("/api/v1/family/motion/consent")
            response = await client.put("/api/v1/family/motion/collection", json={"enabled": True})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["collection_enabled"])

        stored = self.fake.tables["motion_consents"][0]
        self.assertEqual(stored["user_id"], WIFE)
        self.assertTrue(stored["consent_granted"])
        self.assertTrue(stored["collection_enabled"])
        # 저장된 행에 카메라 프레임/영상/landmark 관련 키가 전혀 없다.
        self.assertEqual(set(stored.keys()) & set(FORBIDDEN_FIELD_HINTS), set())

    async def test_withdraw_turns_off_both_but_keeps_a_settings_row_not_camera_data(self) -> None:
        async with client_for(self.fake) as client:
            await client.put("/api/v1/family/motion/consent")
            await client.put("/api/v1/family/motion/collection", json={"enabled": True})
            response = await client.delete("/api/v1/family/motion/consent")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertFalse(body["consent_granted"])
        self.assertFalse(body["collection_enabled"])
        self.assertEqual(len(self.fake.tables["motion_consents"]), 1)  # 여전히 설정 행 1개뿐

    async def test_husband_toggling_only_affects_his_own_nonexistent_row(self) -> None:
        """남편용 별도 엔드포인트나 파라미터가 없다 — 아내 동의 설정에 접근할 경로 자체가 없다."""
        async with client_for(self.fake) as client:
            await client.put("/api/v1/family/motion/consent")  # 아내가 동의

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="husband-1")
        async with client_for(self.fake) as client:
            response = await client.get("/api/v1/family/motion/privacy")
        self.assertFalse(response.json()["consent_granted"])  # 남편 본인 몫(없음)만 본다

    async def test_storage_failure_returns_503(self) -> None:
        def raise_connect_error(name: str):
            import httpx

            raise httpx.ConnectError("down")

        app.dependency_overrides[get_family_service] = lambda: FamilyService(
            SupabaseFamilyRepository(SimpleNamespace(table=raise_connect_error), fallback=StubFamilyRepository())
        )
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost") as client:
            response = await client.get("/api/v1/family/motion/privacy")
        self.assertEqual(response.status_code, 503)


class MovementProtectedBoundaryTest(unittest.TestCase):
    """Protected 스키마/저장소 경계를 바꾸지 않았음을 재확인한다(읽기 전용 검사)."""

    def test_posture_event_has_no_frame_or_landmark_fields(self) -> None:
        fields = set(PostureEvent.model_fields.keys())
        offending = {f for f in fields if any(hint in f.lower() for hint in FORBIDDEN_FIELD_HINTS)}
        self.assertEqual(offending, set())

    def test_calibration_profile_stores_only_a_count_not_raw_frames(self) -> None:
        fields = set(CalibrationProfileSchema.model_fields.keys())
        self.assertIn("frame_count", fields)  # 개수(정수)만 — 프레임 원본 아님
        offending = {f for f in fields if any(hint in f.lower() for hint in ("landmark", "frame_data", "video", "image"))}
        self.assertEqual(offending, set())

    def test_movement_event_repository_boundary_already_exists(self) -> None:
        """STEP 14: "필요하다면 MovementEventRepository 경계만 추가한다" — 이미
        EventStore Protocol + InMemory/Supabase 구현체가 그 경계이므로 새로
        만들지 않는다. Demo는 계속 InMemory를 써도 된다."""
        self.assertTrue(hasattr(EventStore, "record"))
        self.assertTrue(hasattr(EventStore, "list_events"))
        self.assertTrue(callable(InMemoryEventStore))
        self.assertTrue(callable(SupabaseEventStore))


if __name__ == "__main__":
    unittest.main()
