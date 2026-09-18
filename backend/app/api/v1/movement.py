"""모션 인식 기능 API (B-1/B-3, 2026-09-15; /report/daily는 2026-09-15 추가 반영).

/live/stream(WebSocket)이 실제 카메라 프레임을 받아 SessionManager로 처리하고,
/live·/events·/report/daily 전부 실제 값을 반환한다(목업 없음). 이벤트/캘리브레이션은
2026-09-16부터 Supabase(`SupabaseEventStore`/`SupabaseCalibrationStore`)에 실제로
저장된다(그 전엔 InMemory/로컬 파일).

엔드포인트 설계 배경(docs/movement/구현계획서_v3.md §3/§6 참고):
- /live는 임계 이벤트 발생 시 서버가 먼저 보내는 푸시 알림이 아니라, 호출 시점 기준
  누적 상태를 돌려주는 풀(pull) 조회다 (W-MOTION-001).
- 카메라 연동은 데모 전용이다. 이 모듈의 세션 상태(_current_session_id)는 "동시에
  한 명만 시연한다"는 전제의 전역 변수이며, 실제 다중 사용자 서비스에서는 인증
  컨텍스트에서 세션을 조회하는 방식으로 교체해야 한다 (§4 참고).

인증(2026-09-16 추가): REST(`/live`, `/events`, `/report/daily`)는 `profile.py`와
동일하게 `Authorization: Bearer <token>` + `get_current_user`를 쓴다. WebSocket은
브라우저가 핸드셰이크에 커스텀 헤더를 못 보내므로 `?token=<access_token>` 쿼리
파라미터로 받는다(팀 결정) — 검증 로직(`get_user_from_token`)은 REST와 동일하다.
`DEMO_USER_ID`는 이제 안 쓴다.

WebSocket 프로토콜 (프론트 B-4가 구현할 대상):
1. 연결하면 서버가 세션을 만들고, 기존 캘리브레이션이 없으면 캘리브레이션 단계로
   들어간다. 클라이언트는 JPEG로 인코딩한 프레임을 바이너리로 계속 보낸다.
2. 캘리브레이션 중에는 서버가 매 프레임 {"type": "calibration_progress", ...}를
   보내고, 충분히 모이면 {"type": "calibration_done"}을 보낸 뒤 실시간 판정으로
   전환한다.
3. 실시간 판정 단계에서는 매 프레임 {"type": "frame", "data": PostureFrameState}를
   보낸다.
4. 연결이 끊기면 서버가 세션을 정리한다(열려 있던 이벤트는 그 시점으로 닫아 기록).
"""

from __future__ import annotations

import re
import time
import uuid
from collections.abc import Iterator
from datetime import date as date_type
from datetime import datetime, timezone

import cv2
import numpy as np
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from mediapipe.tasks.python.vision import RunningMode

from app.api.v1.family import get_family_service
from app.core.config import ALLOWED_ORIGIN_REGEX
from app.core.security import CurrentUser, get_current_user, get_user_from_token
from app.domains.errors import DomainStorageError
from app.domains.family.service import FamilyServicePort
from app.schemas.movement import DailyReportSummary, LiveAccumulatedState, PostureEvent
from app.services.movement.calibration import CalibrationCollector, CalibrationStorageError, SupabaseCalibrationStore
from app.services.movement.events import EventStorageError, EventStore, SupabaseEventStore
from app.services.movement.pose_extractor import PoseExtractor
from app.services.movement.report import generate_daily_report
from app.services.movement.session_manager import SessionManager
from app.services.supabase_service import SupabaseService, get_supabase_service

_ORIGIN_PATTERN = re.compile(ALLOWED_ORIGIN_REGEX)

router = APIRouter(prefix="/movement", tags=["movement"])

STORAGE_UNAVAILABLE = "모션 인식 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."
WS_CLOSE_CONSENT_REQUIRED = 4003  # 동의 없음 또는 수집 OFF (1008=origin/토큰, 1011=서버 오류)

# SupabaseEventStore/SupabaseCalibrationStore는 SupabaseService만 들고 있고
# .client(실제 연결)는 첫 DB 요청 때 지연 생성하므로, SUPABASE_* 환경변수가
# 아직 없어도 이 모듈 import(=앱 기동) 자체는 실패하지 않는다(각 store의
# docstring 참고). _session_manager는 세션 상태를 들고 있어야 하는 진짜
# singleton이라 ProfileService처럼 요청마다 새로 만들 수 없다.
_calibration_store = SupabaseCalibrationStore(get_supabase_service())
_event_store = SupabaseEventStore(get_supabase_service())
_session_manager = SessionManager(calibration_store=_calibration_store, event_store=_event_store)

# 데모 전용 전역 상태: "지금 시연 중인 세션 하나"를 가리킨다 (모듈 docstring 참고).
_current_session_id: uuid.UUID | None = None


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_session_manager() -> SessionManager:
    return _session_manager


def get_event_store() -> EventStore:
    return _event_store


def get_pose_extractor() -> Iterator[PoseExtractor]:
    """WS 연결 하나당 하나씩 만들고, 연결이 끝나면 반드시 닫는다.

    테스트에서는 이 의존성을 오버라이드해서 실제 MediaPipe 없이 가짜
    extractor를 주입할 수 있다(진짜 사람 사진 없이도 프로토콜을 검증하기 위함).
    """
    extractor = PoseExtractor(RunningMode.VIDEO)
    try:
        yield extractor
    finally:
        extractor.close()


def _decode_jpeg_to_rgb(data: bytes) -> np.ndarray:
    bgr = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError("프레임을 이미지로 디코딩할 수 없습니다 (JPEG bytes가 아님).")
    return cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)


def _is_allowed_origin(origin: str | None) -> bool:
    """HTTP 요청에 이미 걸려있는 CORS 규칙(ALLOWED_ORIGIN_REGEX)을 WebSocket
    핸드셰이크에도 똑같이 적용한다. CORSMiddleware는 WebSocket에는 적용되지
    않아서(2026-09-15 발견), 여기서 따로 확인해야 한다."""
    return origin is not None and _ORIGIN_PATTERN.fullmatch(origin) is not None


@router.websocket("/live/stream")
async def stream_live(
    websocket: WebSocket,
    token: str | None = Query(default=None),
    manager: SessionManager = Depends(get_session_manager),
    extractor: PoseExtractor = Depends(get_pose_extractor),
    supabase: SupabaseService = Depends(get_supabase_service),
    family: FamilyServicePort = Depends(get_family_service),
) -> None:
    if not _is_allowed_origin(websocket.headers.get("origin")):
        await websocket.close(code=1008)
        return

    # 브라우저 WebSocket API는 Authorization 헤더를 못 보내므로, access token을
    # 쿼리 파라미터로 받는다(2026-09-16 결정 — docs/api.md 참고). 다른 REST
    # 엔드포인트(get_current_user)와 검증 로직 자체는 동일하다.
    if token is None:
        await websocket.close(code=1008)
        return
    try:
        user = get_user_from_token(token, supabase)
    except HTTPException:
        await websocket.close(code=1008)
        return

    # NFR-012 / DOMAIN_OWNERSHIP.md: 동의(motion_consents)가 없거나 수집 OFF면 연결 자체를
    # 거부한다. 코드 4003(앱 정의)으로 닫아 origin/토큰 실패(1008)와 구분한다 — 프론트가
    # "동의가 필요해요" 안내를 띄울 수 있게. 동의 조회가 실패하면 열어주지 않고 1011로 닫는다.
    try:
        privacy = family.motion_privacy(user.id)
    except DomainStorageError:
        await websocket.close(code=1011)
        return
    if not (privacy.consent_granted and privacy.collection_enabled):
        await websocket.close(code=WS_CLOSE_CONSENT_REQUIRED)
        return

    global _current_session_id
    await websocket.accept()

    session_id = manager.start_session(uuid.UUID(user.id))
    _current_session_id = session_id
    collector: CalibrationCollector | None = None
    if not manager.has_calibration(session_id):
        collector = CalibrationCollector(extractor)

    start = time.monotonic()
    last_timestamp_ms = -1

    def next_timestamp_ms() -> int:
        nonlocal last_timestamp_ms
        last_timestamp_ms = max(last_timestamp_ms + 1, int((time.monotonic() - start) * 1000))
        return last_timestamp_ms

    try:
        while True:
            data = await websocket.receive_bytes()
            rgb_frame = _decode_jpeg_to_rgb(data)
            timestamp_ms = next_timestamp_ms()

            if collector is not None:
                collector.add_frame(rgb_frame, timestamp_ms)
                await websocket.send_json(
                    {
                        "type": "calibration_progress",
                        "collected": collector.collected,
                        "target": collector.num_frames,
                    }
                )
                if collector.done:
                    manager.set_calibration(session_id, collector.build_profile())
                    collector = None
                    await websocket.send_json({"type": "calibration_done"})
                continue

            frame_state = manager.process_frame(session_id, extractor, rgb_frame, timestamp_ms)
            await websocket.send_json({"type": "frame", "data": frame_state.model_dump(mode="json")})
    except WebSocketDisconnect:
        pass
    except (EventStorageError, CalibrationStorageError):
        # DB(Supabase) 요청 실패로 프레임 처리가 더 이상 의미 없어졌다 — 연결을
        # 정리하고 닫는다. 원인은 각 store가 이미 logger.exception으로 남겼다.
        await websocket.close(code=1011)
    finally:
        try:
            manager.end_session(session_id)
        except (EventStorageError, CalibrationStorageError):
            pass
        if _current_session_id == session_id:
            _current_session_id = None


@router.get("/live", response_model=LiveAccumulatedState)
def get_live_state(
    user: CurrentUser = Depends(get_current_user),
    manager: SessionManager = Depends(get_session_manager),
) -> LiveAccumulatedState:
    """실시간 탭 조회 (W-MOTION-001). 활성 세션이 없으면 404.

    지금은 데모 전용 단일 세션 모델이라(모듈 docstring 참고) 로그인한 사용자와
    무관하게 "지금 시연 중인 세션 하나"를 그대로 반환한다 — 이 엔드포인트는
    로그인을 요구할 뿐, 세션 소유자 검증까지는 하지 않는다. 다중 사용자 서비스로
    갈 때 반드시 세션을 사용자별로 조회하도록 바꿔야 한다.
    """
    if _current_session_id is None:
        raise HTTPException(
            status_code=404,
            detail="활성 세션이 없습니다. 먼저 /movement/live/stream(WebSocket)으로 연결하세요.",
        )
    return manager.get_live_state(_current_session_id)


@router.get("/events", response_model=list[PostureEvent])
def list_events(
    user: CurrentUser = Depends(get_current_user),
    event_store: EventStore = Depends(get_event_store),
) -> list[PostureEvent]:
    try:
        return event_store.list_events(uuid.UUID(user.id))
    except EventStorageError as error:
        raise _storage_unavailable() from error


@router.get("/report/daily", response_model=DailyReportSummary)
def get_daily_report(
    target_date: date_type | None = Query(default=None, alias="date"),
    user: CurrentUser = Depends(get_current_user),
    event_store: EventStore = Depends(get_event_store),
) -> DailyReportSummary:
    """일일 리포트 조회 (§5.9). date 쿼리 파라미터가 없으면 오늘(UTC 기준) 리포트."""
    try:
        return generate_daily_report(
            event_store, uuid.UUID(user.id), target_date or datetime.now(timezone.utc).date()
        )
    except EventStorageError as error:
        raise _storage_unavailable() from error
