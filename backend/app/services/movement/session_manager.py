"""세션(사용자) 단위로 RuleEngine/EmaSmoother/캘리브레이션을 묶어서 관리한다 (계획서 B-2).

지금까지 `tools/motion_demo/__main__.py`가 웹캠 실행 한 번마다 즉석으로 만들던
"PoseExtractor + EmaSmoother + RuleEngine + CalibrationProfile" 묶음을, 여러
세션(사용자)을 동시에 다룰 수 있는 재사용 가능한 컴포넌트로 옮긴 것이다.
나중에 B-1(WebSocket)이 이 클래스를 그대로 호출하면 된다.

이 파일에서 새로 추가되는 로직(기존에 없던 것)은 두 가지뿐이다:
1. FrameJudgement → PostureEvent 변환: 라벨이 Repeated Load 이상으로 올라간
   시점부터 다시 Normal로 내려가거나 자세가 바뀌는 시점까지를 구간형 이벤트로
   묶어 EventStore에 기록한다 (schemas/movement.py 2026-09-14 설계 결정).
   Sit-to-Stand는 순간 이벤트로 별도 기록한다.
2. LiveAccumulatedState 집계: "실시간 탭" 조회(W-MOTION-001, pull 방식)에 쓸
   자세유형별 누적 횟수/지속시간을 이벤트가 닫힐 때마다 갱신한다.

트리거 사유(EventTrigger) 판단은 FrameJudgement에 남아있는 신호만으로 추정한
근사치다: Prolonged Load면 STATE_DURATION, 그 다음이면 REPEATED_COUNT로 본다.
이벤트가 지속되는 동안 더 강한 사유로 바뀌어도 소급 갱신하지 않는다 — "왜
시작됐는지"만 기록하는 단순화이며, 실제 서비스에서 더 정밀한 판단이 필요해지면
여기를 고친다.

3. (2026-09-15) 누적 전방굴곡 위험(Frankel 등 연구 기반)은 더 이상 실시간
   라벨을 바꾸지 않는다. 대신 세션이 끝날 때(end_session) 그 세션에서 관찰된
   누적 시간을 trigger_reason=CUMULATIVE_RESEARCH_THRESHOLD인 PostureEvent
   하나로 남겨서, report.py가 일일 리포트에서만 "오늘 누적 시간" 형태로
   보여줄 수 있게 한다. LiveAccumulatedState 집계(_update_tally)에는 반영하지
   않는다 — 실시간 화면에서 이 개념이 안 보여야 하기 때문이다.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from uuid import UUID

from ...schemas.movement import (
    BurdenLabel,
    EventTrigger,
    Landmark,
    LiveAccumulatedState,
    PostureEvent,
    PostureFrameState,
    PostureType,
    PostureTypeTally,
    resolve_body_part,
)

from .calibration import CalibrationProfile, CalibrationStore
from .events import EventStore
from .features import EmaSmoother, compute_features
from .pose_extractor import LANDMARK_NAMES, PoseExtractor
from .rule_engine import LABEL_LEVEL, PROLONGED_LOAD, RuleEngine


@dataclass
class _OpenEvent:
    started_at: datetime
    posture_type: PostureType
    trigger_reason: EventTrigger
    peak_burden_label: BurdenLabel


@dataclass
class _Session:
    session_id: UUID
    user_id: UUID
    started_at: datetime
    rule_engine: RuleEngine = field(default_factory=RuleEngine)
    smoother: EmaSmoother = field(default_factory=EmaSmoother)
    calibration: CalibrationProfile | None = None
    open_event: _OpenEvent | None = None
    tallies: dict[PostureType, PostureTypeTally] = field(default_factory=dict)
    latest_judgement_posture: PostureType = PostureType.UNKNOWN
    latest_judgement_label: BurdenLabel = BurdenLabel.NORMAL
    latest_cumulative_bend_sec: float = 0.0
    latest_research_threshold_crossed: bool = False


def _derive_trigger(burden_label: str) -> EventTrigger:
    if burden_label == PROLONGED_LOAD:
        return EventTrigger.STATE_DURATION
    return EventTrigger.REPEATED_COUNT


class SessionManager:
    """세션 생성부터 프레임 처리, 실시간 탭 조회까지의 진입점.

    PoseExtractor는 호출부(WebSocket 핸들러 등)가 만들어서 넘겨준다 — 어떤
    RunningMode·모델 경로를 쓸지는 이 클래스가 알 필요가 없고, 테스트에서
    가짜 extractor를 주입하기도 쉬워진다.
    """

    def __init__(self, calibration_store: CalibrationStore, event_store: EventStore):
        self._calibration_store = calibration_store
        self._event_store = event_store
        self._sessions: dict[UUID, _Session] = {}

    def start_session(self, user_id: UUID) -> UUID:
        """세션을 새로 만든다. 기존 캘리브레이션이 있으면 자동으로 불러온다."""
        session_id = uuid.uuid4()
        session = _Session(
            session_id=session_id,
            user_id=user_id,
            started_at=datetime.now(timezone.utc),
        )
        session.calibration = self._calibration_store.load(user_id)
        self._sessions[session_id] = session
        return session_id

    def has_calibration(self, session_id: UUID) -> bool:
        """세션에 캘리브레이션이 이미 있는지. WS 핸들러가 캘리브레이션 단계를
        건너뛸지 판단할 때 쓴다 (start_session이 저장소에서 자동으로 불러온
        기존 프로필이 있을 수 있음)."""
        return self._sessions[session_id].calibration is not None

    def set_calibration(self, session_id: UUID, profile: CalibrationProfile) -> None:
        """캘리브레이션 결과를 세션에 붙이고 저장소에도 반영한다."""
        session = self._sessions[session_id]
        session.calibration = profile
        self._calibration_store.save(session.user_id, profile)

    def end_session(self, session_id: UUID) -> None:
        """세션을 종료한다. 열려 있던 이벤트가 있으면 지금 시점으로 닫아 기록하고,
        그날 관찰된 누적 전방굴곡 시간을 리포트용으로 하나 남긴다."""
        session = self._sessions.pop(session_id, None)
        if session is None:
            return
        now = datetime.now(timezone.utc)
        if session.open_event is not None:
            self._close_event(session, now)
        self._record_cumulative_bend(session, now)

    def process_frame(self, session_id: UUID, extractor: PoseExtractor, rgb_frame, timestamp_ms: int) -> PostureFrameState:
        """프레임 하나를 처리해 실시간 오버레이용 상태를 돌려준다.

        내부적으로 판정(update_judgement)까지 호출하므로, 이벤트/누적 집계도
        같이 갱신된다. landmark 추출까지 포함하므로 실제 PoseExtractor가
        필요하다 (단위 테스트는 update_judgement를 직접 쓰는 걸 권장).
        """
        session = self._sessions[session_id]
        pose = extractor.extract(rgb_frame, timestamp_ms=timestamp_ms)
        features = compute_features(pose) if pose is not None else None
        valid = features is not None and features.valid and session.calibration is not None

        trunk_abs = float("nan")
        trunk_dev = knee_dev = float("nan")
        if valid:
            trunk_abs = session.smoother.update("trunk", features.trunk_flexion_3d)
            knee_abs = session.smoother.update("knee", features.knee_mean_3d)
            trunk_dev = session.calibration.trunk_deviation(trunk_abs)
            knee_dev = session.calibration.knee_deviation(knee_abs)

        frame_state = self.update_judgement(
            session_id,
            t=timestamp_ms / 1000,
            valid=valid,
            trunk_dev=trunk_dev,
            knee_dev=knee_dev,
            trunk_flexion_abs=trunk_abs,
        )

        if pose is not None:
            frame_state.landmarks = [
                Landmark(
                    name=name,
                    x=float(pose.pixel_xy[i][0]),
                    y=float(pose.pixel_xy[i][1]),
                    visibility=float(pose.visibility[i]),
                    world_x=float(pose.world_xyz[i][0]),
                    world_y=float(pose.world_xyz[i][1]),
                    world_z=float(pose.world_xyz[i][2]),
                )
                for i, name in enumerate(LANDMARK_NAMES)
            ]
        return frame_state

    def update_judgement(
        self,
        session_id: UUID,
        *,
        t: float,
        valid: bool,
        trunk_dev: float = float("nan"),
        knee_dev: float = float("nan"),
        trunk_flexion_abs: float = float("nan"),
    ) -> PostureFrameState:
        """랜드마크/오버레이 없이 판정만 진행한다. 단위 테스트는 이걸 쓴다.

        rule_engine.update()를 호출하고, 그 결과로 이벤트 구간 추적과
        실시간 탭 누적 집계를 갱신한 뒤 PostureFrameState(landmarks=[])를
        반환한다.
        """
        session = self._sessions[session_id]
        judgement = session.rule_engine.update(t, valid, trunk_dev, knee_dev, trunk_flexion_abs)
        occurred_at = session.started_at + timedelta(seconds=t)

        posture = PostureType(judgement.posture)
        burden_label = BurdenLabel(judgement.burden_label)
        session.latest_judgement_posture = posture
        session.latest_judgement_label = burden_label
        session.latest_cumulative_bend_sec = judgement.cumulative_bend_sec
        session.latest_research_threshold_crossed = judgement.research_threshold_crossed

        if judgement.event == "sit_to_stand":
            self._record_instant_event(
                session, occurred_at, posture, burden_label, EventTrigger.SIT_TO_STAND
            )
        else:
            self._track_open_event(session, occurred_at, posture, burden_label, judgement)

        return PostureFrameState(
            session_id=session_id,
            occurred_at=occurred_at,
            posture=posture,
            burden_label=burden_label,
            state_duration_sec=judgement.state_duration,
            cumulative_bend_sec=judgement.cumulative_bend_sec,
            landmarks=[],
        )

    def get_live_state(self, session_id: UUID) -> LiveAccumulatedState:
        """실시간 탭 조회 응답 (W-MOTION-001). 호출 시점 기준 누적 상태 스냅샷."""
        session = self._sessions[session_id]
        return LiveAccumulatedState(
            session_id=session_id,
            as_of=datetime.now(timezone.utc),
            current_posture=session.latest_judgement_posture,
            current_burden_label=session.latest_judgement_label,
            cumulative_bend_sec=session.latest_cumulative_bend_sec,
            tallies=list(session.tallies.values()),
        )

    # -- 이벤트 구간 추적 -------------------------------------------------

    def _track_open_event(
        self,
        session: _Session,
        occurred_at: datetime,
        posture: PostureType,
        burden_label: BurdenLabel,
        judgement,
    ) -> None:
        level = LABEL_LEVEL[judgement.burden_label]

        if level == 0:
            if session.open_event is not None:
                self._close_event(session, occurred_at)
            return

        if session.open_event is not None and session.open_event.posture_type != posture:
            # escalation이 유지된 채로 자세가 바뀜 — 이전 구간을 닫고 새로 연다.
            self._close_event(session, occurred_at)

        if session.open_event is None:
            # judgement.state_duration만큼 거슬러 올라가 "라벨이 올라간 순간"이 아니라
            # "그 자세가 실제로 시작된 시점"을 이벤트 시작으로 잡는다. 그래야
            # Prolonged Load처럼 지속시간 임계값을 넘어야 격상되는 라벨의 duration_sec가
            # "격상된 후 경과 시간"이 아니라 "그 부담 자세가 실제로 지속된 시간"이 된다.
            trigger = _derive_trigger(judgement.burden_label)
            session.open_event = _OpenEvent(
                started_at=occurred_at - timedelta(seconds=judgement.state_duration),
                posture_type=posture,
                trigger_reason=trigger,
                peak_burden_label=burden_label,
            )
        else:
            session.open_event.peak_burden_label = max(
                session.open_event.peak_burden_label, burden_label, key=lambda label: LABEL_LEVEL[label.value]
            )

    def _close_event(self, session: _Session, ended_at: datetime) -> None:
        open_event = session.open_event
        if open_event is None:
            return
        session.open_event = None

        duration_sec = max((ended_at - open_event.started_at).total_seconds(), 0.0)
        event = PostureEvent(
            event_id=uuid.uuid4(),
            user_id=session.user_id,
            session_id=session.session_id,
            posture_type=open_event.posture_type,
            burden_label=open_event.peak_burden_label,
            started_at=open_event.started_at,
            ended_at=ended_at,
            duration_sec=duration_sec,
            trigger_reason=open_event.trigger_reason,
            cumulative_bend_sec=session.latest_cumulative_bend_sec,
            created_at=datetime.now(timezone.utc),
        )
        self._event_store.record(event)
        self._update_tally(session, event)

    def _record_instant_event(
        self,
        session: _Session,
        occurred_at: datetime,
        posture: PostureType,
        burden_label: BurdenLabel,
        trigger: EventTrigger,
    ) -> None:
        event = PostureEvent(
            event_id=uuid.uuid4(),
            user_id=session.user_id,
            session_id=session.session_id,
            posture_type=posture,
            burden_label=burden_label,
            started_at=occurred_at,
            ended_at=occurred_at,
            duration_sec=0.0,
            trigger_reason=trigger,
            cumulative_bend_sec=session.latest_cumulative_bend_sec,
            created_at=datetime.now(timezone.utc),
        )
        self._event_store.record(event)
        self._update_tally(session, event)

    def _record_cumulative_bend(self, session: _Session, ended_at: datetime) -> None:
        """세션 종료 시점까지 관찰된 누적 전방굴곡 시간을 리포트용으로 기록한다.

        일부러 _update_tally()를 안 부른다 — "실시간 탭"/오버레이에는 이 개념이
        보이면 안 된다는 2026-09-15 결정 때문이다(report.py만 trigger_reason으로
        이 이벤트를 따로 골라 그날 총합을 낸다). duration_sec은 이 이벤트 "자체"의
        길이가 아니라 세션 동안 관찰된 누적 굴곡 시간을 담는 용도로 쓴다 — 다른
        이벤트들과 의미가 다르니 헷갈리지 않도록 주의.
        """
        if session.latest_cumulative_bend_sec <= 0:
            return
        event = PostureEvent(
            event_id=uuid.uuid4(),
            user_id=session.user_id,
            session_id=session.session_id,
            posture_type=PostureType.BENDING,
            burden_label=(
                BurdenLabel.PROLONGED_LOAD
                if session.latest_research_threshold_crossed
                else BurdenLabel.NORMAL
            ),
            started_at=session.started_at,
            ended_at=ended_at,
            duration_sec=session.latest_cumulative_bend_sec,
            trigger_reason=EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD,
            cumulative_bend_sec=session.latest_cumulative_bend_sec,
            created_at=ended_at,
        )
        self._event_store.record(event)

    def _update_tally(self, session: _Session, event: PostureEvent) -> None:
        existing = session.tallies.get(event.posture_type)
        if existing is None:
            session.tallies[event.posture_type] = PostureTypeTally(
                posture_type=event.posture_type,
                body_part=resolve_body_part(event.posture_type, event.trigger_reason),
                event_count=1,
                total_duration_sec=event.duration_sec,
            )
        else:
            existing.event_count += 1
            existing.total_duration_sec += event.duration_sec
