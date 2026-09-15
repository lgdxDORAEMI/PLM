"""모션 인식 기능 API (B-1/B-3, 2026-09-15; /report/daily는 2026-09-15 추가 반영).

/live/stream(WebSocket)이 실제 카메라 프레임을 받아 SessionManager로 처리하고,
/live·/events·/report/daily 전부 실제 값을 반환한다(목업 없음).

엔드포인트 설계 배경(2026-09-15 팀 결정, docs/movement/구현계획서_v3.md §4/§5.7 참고):
- /live는 임계 이벤트 발생 시 서버가 먼저 보내는 푸시 알림이 아니라, 호출 시점 기준
  누적 상태를 돌려주는 풀(pull) 조회다 (W-MOTION-001).
- 카메라 연동은 데모 전용이다. 이 모듈의 세션 상태(_current_session_id)는 "동시에
  한 명만 시연한다"는 전제의 전역 변수이며, 실제 다중 사용자 서비스에서는 인증
  컨텍스트에서 세션을 조회하는 방식으로 교체해야 한다 (§4 참고).

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
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from mediapipe.tasks.python.vision import RunningMode

from app.core.config import ALLOWED_ORIGIN_REGEX
from app.schemas.movement import DEMO_USER_ID, DailyReportSummary, LiveAccumulatedState, PostureEvent
from app.services.movement.calibration import CalibrationCollector, LocalFileCalibrationStore
from app.services.movement.events import InMemoryEventStore
from app.services.movement.pose_extractor import PoseExtractor
from app.services.movement.report import generate_daily_report
from app.services.movement.session_manager import SessionManager

_ORIGIN_PATTERN = re.compile(ALLOWED_ORIGIN_REGEX)

router = APIRouter(prefix="/movement", tags=["movement"])

_calibration_store = LocalFileCalibrationStore()
_event_store = InMemoryEventStore()
_session_manager = SessionManager(calibration_store=_calibration_store, event_store=_event_store)

# 데모 전용 전역 상태: "지금 시연 중인 세션 하나"를 가리킨다 (모듈 docstring 참고).
_current_session_id: uuid.UUID | None = None


def get_session_manager() -> SessionManager:
    return _session_manager


def get_event_store() -> InMemoryEventStore:
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
    manager: SessionManager = Depends(get_session_manager),
    extractor: PoseExtractor = Depends(get_pose_extractor),
) -> None:
    if not _is_allowed_origin(websocket.headers.get("origin")):
        await websocket.close(code=1008)
        return

    global _current_session_id
    await websocket.accept()

    session_id = manager.start_session(DEMO_USER_ID)
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
    finally:
        manager.end_session(session_id)
        if _current_session_id == session_id:
            _current_session_id = None


@router.get("/live", response_model=LiveAccumulatedState)
def get_live_state(manager: SessionManager = Depends(get_session_manager)) -> LiveAccumulatedState:
    """실시간 탭 조회 (W-MOTION-001). 활성 세션이 없으면 404."""
    if _current_session_id is None:
        raise HTTPException(
            status_code=404,
            detail="활성 세션이 없습니다. 먼저 /movement/live/stream(WebSocket)으로 연결하세요.",
        )
    return manager.get_live_state(_current_session_id)


@router.get("/events", response_model=list[PostureEvent])
def list_events(event_store: InMemoryEventStore = Depends(get_event_store)) -> list[PostureEvent]:
    return event_store.list_events(DEMO_USER_ID)


@router.get("/report/daily", response_model=DailyReportSummary)
def get_daily_report(
    target_date: date_type | None = Query(default=None, alias="date"),
    event_store: InMemoryEventStore = Depends(get_event_store),
) -> DailyReportSummary:
    """일일 리포트 조회 (§5.9). date 쿼리 파라미터가 없으면 오늘(UTC 기준) 리포트."""
    return generate_daily_report(
        event_store, DEMO_USER_ID, target_date or datetime.now(timezone.utc).date()
    )
