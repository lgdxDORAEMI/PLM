"""movement API의 WebSocket 배선(B-1/B-3) 통합 테스트.

실제 MediaPipe 인식 정확도가 아니라 "프레임이 들어왔을 때 캘리브레이션 →
실시간 판정 → 이벤트 기록 → 세션 정리"라는 배선 자체를 검증한다. 그래서
PoseExtractor를 진짜 사람 사진 없이도 원하는 자세를 그대로 재현하는
가짜로 교체한다 (get_pose_extractor 의존성 오버라이드).

judgement 로직 자체(각도 임계값, 지속시간 규칙)는 이미
tools/motion_demo/test_motion.py의 SessionManagerTest에서 합성 dev 값으로
검증했으므로 여기서 다시 검증하지 않는다. 여기서는 Sit-to-Stand처럼 실제
경과시간이 1초 남짓만 필요한 시나리오로 "이 배선이 실제로 동작하는가"만 확인한다.

2026-09-16부터 movement.py의 _calibration_store/_event_store는 Supabase 구현체라
실제 네트워크가 필요하다. 그래서 이 테스트에서는 SessionManager/EventStore를
InMemory/로컬 파일 기반으로 오버라이드하고(get_session_manager, get_event_store),
인증도 실제 Supabase 대신 가짜로 오버라이드한다(get_current_user, get_supabase_service)
— test_profile.py의 오버라이드 패턴과 동일하다. get_current_user 자체의
401/503 처리는 test_profile.py의 CurrentUserTest에서 이미 검증했으므로 여기서는
다시 검증하지 않고, WebSocket 전용 토큰 검증 경로만 추가로 확인한다.
"""

import time
import unittest
import uuid
from types import SimpleNamespace

import cv2
import numpy as np
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.api.v1.family import get_family_service
from app.api.v1.movement import (
    WS_CLOSE_CONSENT_REQUIRED,
    get_event_store,
    get_pose_extractor,
    get_session_manager,
)
from app.core.security import CurrentUser, get_current_user
from app.domains.errors import DomainStorageError
from app.domains.family.schemas import MotionCollectionInput
from app.domains.family.service import FamilyService
from app.domains.family.stub_repository import StubFamilyRepository
from app.main import app
from app.services.movement.calibration import LocalFileCalibrationStore, _capture_frames_setting
from app.services.movement.events import InMemoryEventStore
from app.services.movement.pose_extractor import PoseResult
from app.services.movement.session_manager import SessionManager
from app.services.supabase_service import get_supabase_service

_TEST_USER_ID = "11111111-1111-1111-1111-111111111111"
_VALID_TOKEN = "test-token"


def _fake_supabase_service(user_id: str) -> SimpleNamespace:
    """SupabaseService 대역. .client.auth.get_user(token)만 흉내 낸다
    (test_profile.py의 supabase_with()와 동일한 duck-typing 방식)."""

    def get_user(token: str):
        if token != _VALID_TOKEN:
            return None
        return SimpleNamespace(user=SimpleNamespace(id=user_id))

    return SimpleNamespace(client=SimpleNamespace(auth=SimpleNamespace(get_user=get_user)))


def _world(overrides: dict[int, tuple[float, float, float]]) -> np.ndarray:
    world = np.zeros((33, 3))
    for idx, xyz in overrides.items():
        world[idx] = xyz
    return world


# 골반 중심 원점(§3.1) 기준 world landmark. 몸통 굴곡각/무릎각만 맞으면 되므로
# 어깨(11,12)/골반(23,24)/무릎(25,26)/발목(27,28)만 채운다.
_STANDING = _world(
    {
        23: (-0.1, 0, 0), 24: (0.1, 0, 0),
        11: (-0.1, -0.5, 0), 12: (0.1, -0.5, 0),
        25: (-0.1, 0.5, 0), 26: (0.1, 0.5, 0),
        27: (-0.1, 1.0, 0), 28: (0.1, 1.0, 0),
    }
)
_SITTING = _world(
    {
        23: (-0.1, 0, 0), 24: (0.1, 0, 0),
        11: (-0.1, -0.5, 0), 12: (0.1, -0.5, 0),
        25: (-0.1, 0.5, 0), 26: (0.1, 0.5, 0),
        27: (-0.1, 0.5, 0.5), 28: (0.1, 0.5, 0.5),  # 무릎-발목이 직각 -> 무릎각 90도
    }
)

_BLANK_JPEG = cv2.imencode(".jpg", np.zeros((240, 320, 3), dtype=np.uint8))[1].tobytes()

# 실제 브라우저가 보내는 것과 같은 형태(로컬 Flutter Web 개발 포트)의 Origin.
_ALLOWED_ORIGIN_HEADERS = {"origin": "http://localhost:5173"}
_STREAM_URL = f"/api/v1/movement/live/stream?token={_VALID_TOKEN}"


class FakePoseExtractor:
    """실제 MediaPipe 없이 지정한 world landmark를 그대로 돌려주는 가짜.

    self.world을 바꾸면 다음 extract() 호출부터 그 자세로 인식된다.
    """

    def __init__(self):
        self.world = _STANDING

    def extract(self, rgb_frame, timestamp_ms=None):
        return PoseResult(
            pixel_xy=np.zeros((33, 2)),
            visibility=np.ones(33),
            world_xyz=self.world,
        )

    def close(self) -> None:
        pass


class MovementWebSocketTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fake_extractor = FakePoseExtractor()

        def override_extractor():
            yield self.fake_extractor

        # 실제 Supabase 없이 배선만 검증하기 위해 인메모리/로컬 파일 저장소로
        # 이 테스트 전용 SessionManager를 만든다 (movement.py의 모듈 싱글턴은
        # 이제 Supabase 구현체라 여기서는 안 쓴다).
        self.event_store = InMemoryEventStore()
        self.calibration_store = LocalFileCalibrationStore()
        self.session_manager = SessionManager(
            calibration_store=self.calibration_store, event_store=self.event_store
        )

        app.dependency_overrides[get_pose_extractor] = override_extractor
        app.dependency_overrides[get_session_manager] = lambda: self.session_manager
        app.dependency_overrides[get_event_store] = lambda: self.event_store
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=_TEST_USER_ID)
        app.dependency_overrides[get_supabase_service] = lambda: _fake_supabase_service(_TEST_USER_ID)

        # NFR-012 게이트: 기본은 동의+수집 ON 상태로 두어 기존 배선 테스트가 그대로 통과한다.
        self.family = FamilyService(StubFamilyRepository())
        self.family.grant_motion_consent(_TEST_USER_ID)
        self.family.set_motion_collection(_TEST_USER_ID, MotionCollectionInput(enabled=True))
        app.dependency_overrides[get_family_service] = lambda: self.family

        self.client = TestClient(app)
        # 이전 테스트 실행이 남긴 기록 때문에 "이미 캘리브레이션 있음"으로
        # 스킵되지 않도록 매 테스트 전/후로 지운다.
        self._calibration_path = self.calibration_store._path(uuid.UUID(_TEST_USER_ID))
        self._calibration_path.unlink(missing_ok=True)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()
        self._calibration_path.unlink(missing_ok=True)

    def test_calibration_then_sit_to_stand_event_is_recorded(self) -> None:
        num_frames = _capture_frames_setting()

        with self.client.websocket_connect(_STREAM_URL, headers=_ALLOWED_ORIGIN_HEADERS) as ws:
            # 캘리브레이션 단계: 서 있는 자세로 num_frames번 보낸다.
            for i in range(num_frames):
                ws.send_bytes(_BLANK_JPEG)
                progress = ws.receive_json()
                self.assertEqual(progress["type"], "calibration_progress")
                self.assertEqual(progress["collected"], i + 1)
            done = ws.receive_json()
            self.assertEqual(done["type"], "calibration_done")

            # 실시간 판정 단계: 앉음 -> (1초 이상 경과) -> 일어섬.
            self.fake_extractor.world = _SITTING
            ws.send_bytes(_BLANK_JPEG)
            sitting_frame = ws.receive_json()
            self.assertEqual(sitting_frame["data"]["posture"], "Sitting")

            time.sleep(1.1)  # rule_engine의 min_sit_duration_sec(1.0s) 이상 경과시키기 위함

            # EmaSmoother가 앉음(knee=90)에서 곧바로 서기(knee=180)로 튀지 않고
            # 몇 프레임에 걸쳐 수렴하므로(§3.2 노이즈 대응), 자세가 실제로
            # Standing으로 바뀌는 프레임까지 여러 번 보낸다.
            self.fake_extractor.world = _STANDING
            stand_up_frame = None
            for _ in range(10):
                ws.send_bytes(_BLANK_JPEG)
                frame = ws.receive_json()
                if frame["data"]["posture"] == "Standing":
                    stand_up_frame = frame
                    break
            self.assertIsNotNone(stand_up_frame, "10프레임 안에 Standing으로 전이되지 않음")
            self.assertEqual(stand_up_frame["data"]["burden_label"], "High-load Action")

        # 연결이 끊겼으니 세션이 정리되어 활성 세션이 없어야 한다.
        live_response = self.client.get("/api/v1/movement/live")
        self.assertEqual(live_response.status_code, 404)

        # 하지만 이벤트는 EventStore에 남아 /events로 조회 가능해야 한다.
        events_response = self.client.get("/api/v1/movement/events")
        self.assertEqual(events_response.status_code, 200)
        events = events_response.json()
        sit_to_stand_events = [e for e in events if e["trigger_reason"] == "sit_to_stand"]
        self.assertEqual(len(sit_to_stand_events), 1)
        self.assertEqual(sit_to_stand_events[0]["burden_label"], "High-load Action")
        self.assertEqual(sit_to_stand_events[0]["duration_sec"], 0.0)

        # 오늘 리포트(기본값)에는 방금 그 이벤트가 집계돼 있어야 한다.
        report_response = self.client.get("/api/v1/movement/report/daily")
        self.assertEqual(report_response.status_code, 200)
        report = report_response.json()
        self.assertEqual(report["top_burdened_body_part"], "knee")
        self.assertTrue(any(a["burden_label"] == "High-load Action" for a in report["aggregates"]))

        # 없는 날짜를 명시하면 그 이벤트와 무관하게 빈 리포트가 나와야 한다
        # (다른 테스트가 이 프로세스에서 EventStore에 뭘 남겼든 이 assertion은 영향받지 않음).
        empty_report_response = self.client.get("/api/v1/movement/report/daily?date=2000-01-01")
        self.assertEqual(empty_report_response.status_code, 200)
        self.assertEqual(empty_report_response.json()["aggregates"], [])

    def test_disallowed_origin_is_rejected(self) -> None:
        with self.assertRaises(WebSocketDisconnect):
            with self.client.websocket_connect(
                _STREAM_URL,
                headers={"origin": "https://evil.example.com"},
            ):
                pass

    def test_missing_origin_is_rejected(self) -> None:
        # 실제 브라우저는 항상 Origin을 보내지만, Origin이 없는 요청까지도
        # "허용된 곳에서 온 게 확인되지 않았다"고 보고 막아야 더 안전하다.
        with self.assertRaises(WebSocketDisconnect):
            with self.client.websocket_connect(_STREAM_URL):
                pass

    def test_missing_token_is_rejected(self) -> None:
        with self.assertRaises(WebSocketDisconnect):
            with self.client.websocket_connect(
                "/api/v1/movement/live/stream", headers=_ALLOWED_ORIGIN_HEADERS
            ):
                pass

    def test_invalid_token_is_rejected(self) -> None:
        with self.assertRaises(WebSocketDisconnect):
            with self.client.websocket_connect(
                "/api/v1/movement/live/stream?token=wrong-token",
                headers=_ALLOWED_ORIGIN_HEADERS,
            ):
                pass

    # --- NFR-012: 동의/수집 게이트 ---

    def _connect_close_code(self) -> int:
        with self.assertRaises(WebSocketDisconnect) as ctx:
            with self.client.websocket_connect(_STREAM_URL, headers=_ALLOWED_ORIGIN_HEADERS):
                pass
        return ctx.exception.code

    def test_no_consent_is_rejected_with_consent_code(self) -> None:
        self.family.withdraw_motion_consent(_TEST_USER_ID)
        self.assertEqual(self._connect_close_code(), WS_CLOSE_CONSENT_REQUIRED)

    def test_consent_but_collection_off_is_rejected(self) -> None:
        self.family.set_motion_collection(_TEST_USER_ID, MotionCollectionInput(enabled=False))
        self.assertEqual(self._connect_close_code(), WS_CLOSE_CONSENT_REQUIRED)

    def test_consent_and_collection_on_proceeds_to_calibration(self) -> None:
        with self.client.websocket_connect(_STREAM_URL, headers=_ALLOWED_ORIGIN_HEADERS) as ws:
            ws.send_bytes(_BLANK_JPEG)
            self.assertEqual(ws.receive_json()["type"], "calibration_progress")

    def test_consent_lookup_failure_rejects_instead_of_opening(self) -> None:
        class BrokenFamily:
            def motion_privacy(self, user_id: str):
                raise DomainStorageError("down")

        app.dependency_overrides[get_family_service] = lambda: BrokenFamily()
        self.assertEqual(self._connect_close_code(), 1011)


if __name__ == "__main__":
    unittest.main()
