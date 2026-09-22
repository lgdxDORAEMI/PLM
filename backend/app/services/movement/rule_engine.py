"""규칙 엔진: 프레임별 자세 분류 → 지속시간/반복 추적 → 부담 라벨 산출.

임계값은 rules.yaml에 외부화되어 있어 코드 수정 없이 튜닝 가능하다 (계획서 §5.5).
프레임 자체의 "부담되는가" 여부는 학습이 아니라 캘리브레이션 기준선 대비
편차(trunk_dev, knee_dev)와 지속시간/반복 횟수로만 판정한다 (계획서 §2.2 근거).
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

import yaml

RULES_PATH = Path(__file__).resolve().parent / "rules.yaml"

# 자세 상태
STANDING = "Standing"
BENDING = "Bending"
SITTING = "Sitting"
UNKNOWN = "Unknown"

# 부담 라벨 (계획서 §2.5)
NORMAL = "Normal"
REPEATED_LOAD = "Repeated Load"
PROLONGED_LOAD = "Prolonged Load"
HIGH_LOAD_ACTION = "High-load Action"

LABEL_LEVEL = {NORMAL: 0, REPEATED_LOAD: 1, PROLONGED_LOAD: 2, HIGH_LOAD_ACTION: 3}


def load_rules(path: Path = RULES_PATH) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


# 임신 주수·체중 기반 Bending 판정 각도 개인화 (rules.yaml의 20도는 이 조정이
# 없을 때 쓰는 상한/fallback). 13주부터 배 무게로 늘어난 상체 부하만큼 판정
# 각도를 낮춘다 — 같은 각도로 숙여도 임신 후반부일수록 허리 부담이 커지기 때문.
PREGNANCY_WEEK_BENDING_ADJUSTMENT_START = 13
EXCESS_ABDOMINAL_MASS_PER_WEEK_KG = 0.29
PRE_PREGNANCY_UPPER_BODY_MASS_FRACTION = 0.58


def compute_bending_threshold_deg(
    pregnancy_week: int, pre_pregnancy_weight_kg: float, base_deg: float = 20.0
) -> float:
    excess_abdominal_mass_kg = EXCESS_ABDOMINAL_MASS_PER_WEEK_KG * max(
        0, pregnancy_week - PREGNANCY_WEEK_BENDING_ADJUSTMENT_START
    )
    pre_pregnancy_upper_body_mass_kg = (
        pre_pregnancy_weight_kg * PRE_PREGNANCY_UPPER_BODY_MASS_FRACTION
    )
    upper_body_mass_ratio = 1 + excess_abdominal_mass_kg / pre_pregnancy_upper_body_mass_kg
    return base_deg / upper_body_mass_ratio


@dataclass
class FrameJudgement:
    t: float
    posture: str
    burden_label: str
    state_duration: float
    bend_reps_in_window: int
    event: str | None = None  # 예: "sit_to_stand"
    # Frankel 등 연구 기반 누적 지표 (절대각 30도 기준, 끊겨도 계속 합산됨)
    cumulative_bend_sec: float = 0.0
    research_threshold_crossed: bool = False


class RuleEngine:
    """한 사람의 시계열 프레임을 순서대로 update()에 넣어 사용한다.

    내부에 상태(현재 자세, 지속시간, 최근 반복 이력)를 유지하므로
    같은 인스턴스는 한 세션(한 사람의 연속 스트림)에만 사용해야 한다.
    """

    def __init__(
        self,
        rules: dict | None = None,
        bending_trunk_dev_min_override: float | None = None,
    ):
        self.rules = rules or load_rules()

        p = self.rules["posture"]
        self.bending_trunk_dev_min = p["bending_trunk_dev_min"]
        if bending_trunk_dev_min_override is not None:
            self.bending_trunk_dev_min = bending_trunk_dev_min_override
        self.sitting_knee_dev_min = p["sitting_knee_dev_min"]
        self.min_state_duration = p["min_state_duration"]
        self.grace_period_sec = p["grace_period_sec"]

        b = self.rules["bending_burden"]
        self.bend_prolonged_after = b["prolonged_after_sec"]
        self.bend_repeated_count = b["repeated_after_count"]
        self.bend_repeated_window = b["repeated_window_sec"]

        s = self.rules["standing_burden"]
        self.stand_prolonged_after = s["prolonged_after_sec"]

        sts = self.rules["sit_to_stand"]
        self.min_sit_duration = sts["min_sit_duration_sec"]

        r = self.rules.get("cumulative_forward_bend_risk")
        self.research_enabled = r is not None
        if self.research_enabled:
            self.research_angle_min = r["absolute_angle_deg"]
            self.research_threshold_sec = r["demo_scaled_seconds"]
            self.research_max_gap = r["max_gap_to_bridge_sec"]

        self._current_posture = UNKNOWN
        self._state_start_t: float | None = None
        self._last_valid_t: float | None = None
        self._sit_start_t: float | None = None
        self._bend_session_ends: deque[float] = deque()

        # Frankel 등 연구 기반 누적 카운터 (개인 상태 전이와 무관하게 별도로 흘러간다)
        self._cumulative_bend_sec = 0.0
        self._last_accum_t: float | None = None

    def classify(self, trunk_dev: float, knee_dev: float) -> str:
        """가시성 있는 프레임 하나의 순간 자세 분류. 무릎 기준이 몸통보다 우선한다
        (숙이면서 무릎도 굽혔다면 '앉음/스쿼트'로 보는 게 더 실제에 가깝다)."""
        if knee_dev <= -self.sitting_knee_dev_min:
            return SITTING
        if trunk_dev >= self.bending_trunk_dev_min:
            return BENDING
        return STANDING

    def _leave_state(self, old_posture: str, new_posture: str, t: float) -> str | None:
        """자세가 바뀔 때(정상 전이든, 추적 끊김으로 인한 강제 전이든) 공통으로
        수행해야 하는 회계 처리. 끊김으로 Unknown에 빠지는 경우도 '그 자세가
        실제로 있었던 것'은 사실이므로 반복 카운트에는 반영해야 한다."""
        event = None

        if old_posture == BENDING:
            bend_duration = t - self._state_start_t if self._state_start_t is not None else 0.0
            if bend_duration >= self.min_state_duration:
                self._bend_session_ends.append(t)

        if old_posture == SITTING and self._sit_start_t is not None:
            sit_duration = t - self._sit_start_t
            # 추적이 끊겨서 Unknown으로 넘어간 경우는 '일어섰다'고 확정할 수 없으므로
            # 실제로 관측된 자세(Standing/Bending)로 전이할 때만 이벤트를 발생시킨다.
            if sit_duration >= self.min_sit_duration and new_posture != UNKNOWN:
                event = "sit_to_stand"

        if new_posture == SITTING:
            self._sit_start_t = t

        return event

    def _accumulate_research_bend(self, t: float, valid: bool, trunk_flexion_abs: float) -> None:
        """Frankel 등 연구 지표: 절대각 기준, 자세 전이와 무관하게 끊김 없이 계속 합산.

        가시성 미달 등으로 유효하지 않은 프레임에서는 last_accum_t를 갱신하지 않는다.
        그래야 추적이 복귀했을 때 간격(dt)이 max_gap_to_bridge_sec를 넘어 자동으로
        누적에서 제외된다 (안 보이던 동안 실제로 숙이고 있었을 수도 있지만,
        확인 안 된 시간은 보수적으로 누적하지 않는다 — rules.yaml 주석 참고).
        """
        if not self.research_enabled:
            return
        if not valid or trunk_flexion_abs != trunk_flexion_abs:  # NaN 체크
            return
        if self._last_accum_t is not None:
            dt = t - self._last_accum_t
            if dt <= self.research_max_gap and trunk_flexion_abs >= self.research_angle_min:
                self._cumulative_bend_sec += dt
        self._last_accum_t = t

    def update(
        self,
        t: float,
        valid: bool,
        trunk_dev: float = float("nan"),
        knee_dev: float = float("nan"),
        trunk_flexion_abs: float = float("nan"),
    ) -> FrameJudgement:
        event: str | None = None
        self._accumulate_research_bend(t, valid, trunk_flexion_abs)

        if not valid:
            if (self._last_valid_t is not None
                    and t - self._last_valid_t <= self.grace_period_sec):
                posture = self._current_posture  # 짧은 끊김: 직전 상태 유지
            else:
                posture = UNKNOWN
                if self._current_posture != UNKNOWN:
                    event = self._leave_state(self._current_posture, posture, t)
                self._current_posture = posture
                self._state_start_t = t
        else:
            self._last_valid_t = t
            posture = self.classify(trunk_dev, knee_dev)

            if posture != self._current_posture:
                event = self._leave_state(self._current_posture, posture, t)
                self._current_posture = posture
                self._state_start_t = t

        state_duration = t - self._state_start_t if self._state_start_t is not None else 0.0

        while self._bend_session_ends and t - self._bend_session_ends[0] > self.bend_repeated_window:
            self._bend_session_ends.popleft()
        bend_reps = len(self._bend_session_ends)

        if posture == BENDING:
            if state_duration >= self.bend_prolonged_after:
                label = PROLONGED_LOAD
            elif bend_reps >= self.bend_repeated_count:
                label = REPEATED_LOAD
            else:
                label = NORMAL
        elif posture == STANDING:
            label = PROLONGED_LOAD if state_duration >= self.stand_prolonged_after else NORMAL
        else:
            label = NORMAL

        # 2026-09-15 결정: 이 누적값은 실시간 라벨을 바꾸는 용도가 아니라
        # 일일 리포트에 "오늘 부담 자세 누적 시간"으로만 보여주기 위한 것이다
        # (SessionManager.end_session()이 세션 종료 시 별도 기록을 남긴다).
        # 그래서 여기서는 계산만 하고, label을 더 이상 강제로 올리지 않는다.
        research_crossed = (
            self.research_enabled and self._cumulative_bend_sec >= self.research_threshold_sec
        )

        if event == "sit_to_stand":
            label = HIGH_LOAD_ACTION

        return FrameJudgement(
            t, posture, label, state_duration, bend_reps, event,
            cumulative_bend_sec=self._cumulative_bend_sec,
            research_threshold_crossed=research_crossed,
        )
