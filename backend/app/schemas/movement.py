"""모션 인식 기능의 API/DB 계약 스키마.

실시간 처리(WebSocket)와 이벤트 저장(DB)이 아직 연결되지 않은 시점에
프론트/DB/리포트 담당자가 먼저 참고할 수 있도록 필드 형태를 확정해둔 것이다.
실제 판정 로직은 backend/app/services/movement/rule_engine.py 등에 있으며,
이 파일은 그 결과를 API로 내보낼 때의 "모양"만 정의한다.

설계 결정 (2026-09-14 논의):
- 이벤트 경계: 구간형. 라벨이 Repeated Load 이상으로 올라간 시점부터 다시
  Normal로 내려간 시점까지를 하나의 PostureEvent로 묶는다. Sit-to-Stand는
  순간 이벤트로 별도 기록한다 (§구현계획서_v3 §2.4, §2.5 참고).
- 시각 표현: 세션 상대초(rule_engine의 t)가 아니라 절대 UTC datetime으로
  저장한다. 세션 시작 시각을 기준으로 변환해서 채운다.
- 실시간 프레임 상태(PostureFrameState)에는 골격 오버레이를 그릴 수 있도록
  33개 landmark 좌표를 포함한다.
- user_id는 Supabase Auth 연동 전까지 DEMO_USER_ID 고정값을 사용한다.

설계 결정 (2026-09-15 팀 논의, docs/requirements/ 정합성 점검 반영):
- 임계 이벤트 발생 시 앱에 먼저 알림을 보내는 **푸시 방식은 채택하지 않는다**
  (W-MOTION-001, UC13 근거). 대신 "실시간 탭"이 조회할 때 그 시점까지의
  누적 상태를 돌려주는 **풀(pull) 방식**으로 제공한다 (LiveAccumulatedState).
- 일일 리포트에는 자세유형뿐 아니라 **부위별(허리·몸통 / 무릎) 최다 부담
  요약**을 포함한다 (W-REPORT-002 근거). 좌우 구분은 현재 판정 로직이
  지원하지 않아 포함하지 않는다 (resolve_body_part() 참고).

TODO (NFR, docs/requirements/04_2_비기능요구사항명세서.md — 2026-09-15 결정: 지금은 주석만,
구현은 실제 마이그레이션 작성 시점으로 미룸):
- NFR-008: PostureEvent/CalibrationProfileSchema가 DB에 저장될 때 민감정보(각도·자세
  기록)는 AES-256 이상으로 암호화되어야 한다. 지금 스키마에는 암호화 여부가 없다.
- NFR-012: 모션 모니터링 동의 철회 시 1분 내 수집이 중단되어야 한다. 지금 스키마에는
  동의/철회 상태를 나타내는 필드가 아예 없다.
- NFR-014: PostureAggregate/DailyReportSummary를 AI 엔진에 넘길 때는 서비스 목적에
  필요한 최소 항목으로 제한해야 한다. 지금은 전체 필드를 그대로 노출하고 있다.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field

# Supabase Auth 연동 전까지 사용하는 고정 데모 사용자 id.
# 인증이 붙으면 각 호출부에서 실제 user_id로 교체하고 이 상수는 제거한다.
DEMO_USER_ID = UUID("00000000-0000-0000-0000-000000000001")


class PostureType(str, Enum):
    """rule_engine.py의 자세 상태 상수와 값이 동일하다 (변환 불필요)."""

    STANDING = "Standing"
    BENDING = "Bending"
    SITTING = "Sitting"
    UNKNOWN = "Unknown"


class BurdenLabel(str, Enum):
    """rule_engine.py의 부담 라벨 상수와 값이 동일하다 (변환 불필요)."""

    NORMAL = "Normal"
    REPEATED_LOAD = "Repeated Load"
    PROLONGED_LOAD = "Prolonged Load"
    HIGH_LOAD_ACTION = "High-load Action"


class EventTrigger(str, Enum):
    """PostureEvent가 왜 생성/격상되었는지. 리포트 문구 선택에도 사용.

    푸시 알림 트리거가 아니라 DB 저장/리포트 집계용 사유 분류다 (2026-09-15 결정 참고).
    """

    STATE_DURATION = "state_duration"
    REPEATED_COUNT = "repeated_count"
    CUMULATIVE_RESEARCH_THRESHOLD = "cumulative_research_threshold"
    SIT_TO_STAND = "sit_to_stand"


class BodyPart(str, Enum):
    """일일 리포트의 "최다 부담 부위" 집계 단위 (W-REPORT-002).

    좌우 무릎을 구분하지 않는 이유: rule_engine.classify()가 좌/우 무릎각의
    평균값(knee_mean_3d)으로만 판정하므로, 지금 판정 로직에는 좌우를 구분할
    근거 데이터가 없다. features.py가 knee_diff_3d(비대칭)를 계산해두고는
    있으나 판정에는 쓰이지 않으므로, 좌우 구분이 필요해지면 그때 확장한다.
    """

    TRUNK = "trunk"
    KNEE = "knee"
    WHOLE_BODY = "whole_body"


# PostureType → BodyPart 기본 매핑. Standing은 특정 관절에 집중된 부담이
# 아니라 전신 정적 부담이라 WHOLE_BODY로 분류한다.
_POSTURE_TO_BODY_PART: dict[PostureType, BodyPart] = {
    PostureType.BENDING: BodyPart.TRUNK,
    PostureType.SITTING: BodyPart.KNEE,
    PostureType.STANDING: BodyPart.WHOLE_BODY,
}


def resolve_body_part(posture_type: PostureType, trigger_reason: EventTrigger | None = None) -> BodyPart:
    """리포트 집계용 부위를 결정한다. posture_type만으로 부족한 경우가 있어 함수로 둔다.

    Sit-to-Stand(HIGH_LOAD_ACTION)는 무릎 부담 이벤트이지만, rule_engine.py는
    전이 "이후" 자세(예: Standing)를 posture_type으로 기록한다. 그래서
    trigger_reason이 SIT_TO_STAND면 posture_type과 무관하게 KNEE로 분류한다.
    """
    if trigger_reason == EventTrigger.SIT_TO_STAND:
        return BodyPart.KNEE
    return _POSTURE_TO_BODY_PART.get(posture_type, BodyPart.WHOLE_BODY)


class Landmark(BaseModel):
    """MediaPipe 33 landmark 중 하나. pose_extractor.PoseResult와 1:1 대응."""

    name: str
    x: float
    y: float
    visibility: float
    world_x: float
    world_y: float
    world_z: float


class PostureFrameState(BaseModel):
    """데모 시연용 실시간 골격 오버레이 표시 전용. DB에는 저장하지 않는다.

    "실시간 탭"이 보여줄 누적 상태는 이게 아니라 LiveAccumulatedState다.
    """

    session_id: UUID
    occurred_at: datetime
    posture: PostureType
    burden_label: BurdenLabel
    state_duration_sec: float
    cumulative_bend_sec: float
    landmarks: list[Landmark] = Field(default_factory=list)


class PostureEvent(BaseModel):
    """일일 리포트 집계와 이벤트 조회 API에 쓰이는 저장 단위."""

    event_id: UUID
    user_id: UUID = DEMO_USER_ID
    session_id: UUID
    posture_type: PostureType
    burden_label: BurdenLabel
    started_at: datetime
    ended_at: datetime
    duration_sec: float
    trigger_reason: EventTrigger
    rep_count_in_window: int | None = None
    cumulative_bend_sec: float | None = None
    created_at: datetime


class CalibrationProfileSchema(BaseModel):
    """calibration.CalibrationProfile 대응. user_id만 추가되었다."""

    user_id: UUID = DEMO_USER_ID
    baseline_trunk_flexion: float
    baseline_knee_angle: float
    frame_count: int
    captured_at: datetime


class PostureTypeTally(BaseModel):
    """실시간 탭 조회(LiveAccumulatedState)의 자세유형별 누적 한 줄."""

    posture_type: PostureType
    body_part: BodyPart
    event_count: int
    total_duration_sec: float


class LiveAccumulatedState(BaseModel):
    """실시간 탭 조회 응답 (W-MOTION-001). 푸시 알림이 아니라, 조회 시점
    기준으로 그날 세션에 누적된 최신 상태를 돌려주는 풀(pull) 방식이다.
    """

    session_id: UUID
    as_of: datetime
    current_posture: PostureType
    current_burden_label: BurdenLabel
    cumulative_bend_sec: float
    tallies: list[PostureTypeTally] = Field(default_factory=list)


class PostureAggregate(BaseModel):
    """일일 리포트의 자세유형별 집계 한 줄. body_part는 resolve_body_part()로 채운다."""

    posture_type: PostureType
    body_part: BodyPart
    burden_label: BurdenLabel
    count: int
    total_duration_sec: float
    max_duration_sec: float


class DailyReportSummary(BaseModel):
    """일일 리포트 조회 API 응답. report.py(§5.9, 아직 미구현) 산출물 형태."""

    user_id: UUID = DEMO_USER_ID
    date: datetime
    aggregates: list[PostureAggregate] = Field(default_factory=list)
    top_burdened_body_part: BodyPart | None = None
    """W-REPORT-002의 "최다 부담 관절" 요약. aggregates 중 total_duration_sec이
    가장 큰 body_part를 골라 채운다 (동률 처리 등 구체 규칙은 report.py 구현 시 정의)."""
    cumulative_forward_bend_sec: float = 0.0
    """그날 관찰된 절대 30도 이상 전방굴곡 누적 시간(초). Frankel 등 코호트 연구
    근거(§2.5). 2026-09-15부터 실시간 라벨에는 영향을 안 주고 이 필드로만 노출한다
    — SessionManager.end_session()이 세션별로 남긴 이벤트를 report.py가 그날치
    합산한 값이다. aggregates(자세유형×라벨 집계)에는 포함하지 않는다."""
    narratives: list[str] = Field(default_factory=list)
