"""일일 리포트 생성 모듈 (§5.9, 2026-09-15 구현).

EventStore에 쌓인 그날의 PostureEvent를 자세유형×라벨 조합으로 집계해
DailyReportSummary를 만든다. Repeated Load 이상인 조합에만 문구를 붙인다
(Normal 수준까지 리포트에 나열할 필요는 없음).

trigger_reason이 CUMULATIVE_RESEARCH_THRESHOLD인 이벤트는 다른 이벤트들과
성격이 달라서(자세유형×라벨 집계에 안 섞는다) 따로 뽑아 그날 총합만 낸다 —
SessionManager.end_session()이 세션별로 남긴 "그 세션에서 관찰된 누적
전방굴곡 시간"을 그대로 하루 단위로 합친 것이다 (2026-09-15부터, 실시간
라벨에는 더 이상 영향 안 줌).

문구 자체는 report_templates.yaml에 트리거 사유(EventTrigger)별로 외부화했다.
rules.yaml이 판정 임계값을 코드 밖에 둔 것과 같은 이유 — 문헌 근거 표현은
팀이 코드를 안 건드리고 다듬을 일이 많다.
"""

from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from uuid import UUID

import yaml

from ...schemas.movement import (
    BodyPart,
    BurdenLabel,
    DailyReportSummary,
    EventTrigger,
    PostureAggregate,
    PostureEvent,
    PostureType,
    resolve_body_part,
)
from ...utils import dates
from .events import EventStore
from .rule_engine import LABEL_LEVEL, REPEATED_LOAD

TEMPLATES_PATH = Path(__file__).resolve().parent / "report_templates.yaml"

_POSTURE_LABEL_KO = {
    PostureType.BENDING: "허리를 숙이는",
    PostureType.STANDING: "서 있는",
    PostureType.SITTING: "앉아 있는",
    PostureType.UNKNOWN: "판정 불가",
}

_NOTABLE_LEVEL = LABEL_LEVEL[REPEATED_LOAD]

_GroupKey = tuple[PostureType, BurdenLabel]

_BENDING_BURDEN_LABELS = {BurdenLabel.REPEATED_LOAD, BurdenLabel.PROLONGED_LOAD}


def _count_bending_burden_events(normal_events: list[PostureEvent]) -> int:
    """2026-09-16 팀 결정: Bending의 Repeated Load/Prolonged Load, 그리고
    High-load Action(Sit-to-Stand) 포착 횟수를 합쳐 하나의 지표로 노출한다.

    High-load Action은 무릎 동작이라 posture_type이 실제로는 거의 항상
    Standing으로 기록되므로(session_manager._record_instant_event 참고),
    이 라벨만 posture_type 조건 없이 포함한다 — posture_type=Bending으로
    강제 태깅하면 resolve_body_part()의 body_part 분류 의미가 왜곡되기
    때문에, 필터링은 여기 집계 시점에서만 예외 처리한다.
    """
    return sum(
        1
        for e in normal_events
        if (e.posture_type == PostureType.BENDING and e.burden_label in _BENDING_BURDEN_LABELS)
        or e.burden_label == BurdenLabel.HIGH_LOAD_ACTION
    )


def _load_templates() -> dict[str, str]:
    if not TEMPLATES_PATH.exists():
        return {}
    return yaml.safe_load(TEMPLATES_PATH.read_text(encoding="utf-8")) or {}


_TEMPLATES = _load_templates()


def generate_daily_report(
    event_store: EventStore,
    user_id: UUID,
    report_date: date,
) -> DailyReportSummary:
    """report_date(그 날짜, KST 00:00~다음날 00:00) 하루치 이벤트로 리포트를 만든다."""
    start, end = dates.day_bounds_kst(report_date)
    events = event_store.list_events(user_id, start=start, end=end)

    cumulative_events = [e for e in events if e.trigger_reason == EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD]
    normal_events = [e for e in events if e.trigger_reason != EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD]
    cumulative_forward_bend_sec = sum(e.duration_sec for e in cumulative_events)

    groups: dict[_GroupKey, list[PostureEvent]] = defaultdict(list)
    for event in normal_events:
        groups[(event.posture_type, event.burden_label)].append(event)

    aggregates = [_build_aggregate(key, group) for key, group in groups.items()]

    # narratives[0]이 화면에 그대로 노출되므로(2026-09-23 결정), 발생 횟수가
    # 많은 그룹부터, 같으면 더 먼저 발생한 그룹부터 정렬한다. sorted()는 안정
    # 정렬이라 groups(발생 순으로 쌓인 dict)의 원래 순서가 동률 시 유지된다.
    ordered_groups = sorted(groups.items(), key=lambda item: len(item[1]), reverse=True)

    narratives = _build_narratives(ordered_groups)
    if cumulative_forward_bend_sec > 0:
        narratives.append(_build_cumulative_narrative(cumulative_forward_bend_sec))

    return DailyReportSummary(
        user_id=user_id,
        date=start,
        aggregates=aggregates,
        top_burdened_body_part=_pick_top_burdened(aggregates),
        cumulative_forward_bend_sec=cumulative_forward_bend_sec,
        bending_burden_event_count=_count_bending_burden_events(normal_events),
        narratives=narratives,
        posture_summaries=_build_posture_summaries(ordered_groups),
    )


def _build_aggregate(key: _GroupKey, group_events: list[PostureEvent]) -> PostureAggregate:
    posture_type, burden_label = key
    # 그룹 내 이벤트들의 trigger_reason은 거의 항상 같은 body_part로 귀결되므로
    # 대표로 첫 이벤트 하나만 봐도 충분하다 (schemas/movement.py resolve_body_part 참고).
    body_part = resolve_body_part(posture_type, group_events[0].trigger_reason)
    durations = [e.duration_sec for e in group_events]
    return PostureAggregate(
        posture_type=posture_type,
        body_part=body_part,
        burden_label=burden_label,
        count=len(group_events),
        total_duration_sec=sum(durations),
        max_duration_sec=max(durations),
    )


def _pick_top_burdened(aggregates: list[PostureAggregate]) -> BodyPart | None:
    """가장 부담이 큰 부위를 고른다.

    total_duration_sec 합으로만 고르면 안 된다 — Sit-to-Stand는 설계상 항상
    duration_sec=0인 순간 이벤트라서, 아무리 자주 일어나도 지속시간 합으로는
    절대 1위가 될 수 없다(실측: 오늘 12회 관찰돼도 0.0으로 계산됨). 그래서
    "얼마나 오래"가 아니라 "얼마나 심각한 일이 몇 번"으로 본다 — 각 조합의
    count에 라벨 심각도(LABEL_LEVEL)를 곱해 점수화한다.
    """
    if not aggregates:
        return None
    scores: dict[BodyPart, int] = defaultdict(int)
    for agg in aggregates:
        scores[agg.body_part] += agg.count * LABEL_LEVEL[agg.burden_label.value]
    return max(scores, key=lambda part: scores[part])


def _build_narratives(ordered_groups: list[tuple[_GroupKey, list[PostureEvent]]]) -> list[str]:
    """narratives[0]이 화면(실시간 탭 현재 상태 카드)에 그대로 노출되므로, 호출부가
    넘기는 ordered_groups의 순서 자체가 "무엇을 대표로 보여줄지" 정하는
    기준이다(2026-09-23 결정)."""
    narratives: list[str] = []
    for (posture_type, burden_label), group_events in ordered_groups:
        if LABEL_LEVEL[burden_label.value] < _NOTABLE_LEVEL:
            continue

        trigger = Counter(e.trigger_reason for e in group_events).most_common(1)[0][0]
        template = _TEMPLATES.get(trigger.value)
        if template is None:
            continue

        durations = [e.duration_sec for e in group_events]
        narratives.append(
            template.format(
                count=len(group_events),
                total_duration_sec=sum(durations),
                max_duration_sec=max(durations),
                posture_label=_POSTURE_LABEL_KO.get(posture_type, posture_type.value),
            )
        )
    return narratives


def _build_posture_summaries(ordered_groups: list[tuple[_GroupKey, list[PostureEvent]]]) -> list[str]:
    """캘린더/일일 리포트 화면용 짧은 문구(2026-09-23 결정). narratives는 문헌
    인용이 섞인 긴 문장이라 이 두 화면에는 안 맞아서, "{자세} 행동이 {횟수}번
    확인됐어요." 형식으로 따로 만든다. 정렬 기준은 narratives와 동일하게
    호출부의 ordered_groups를 그대로 따른다."""
    summaries: list[str] = []
    for (posture_type, burden_label), group_events in ordered_groups:
        if LABEL_LEVEL[burden_label.value] < _NOTABLE_LEVEL:
            continue
        posture_label = _POSTURE_LABEL_KO.get(posture_type, posture_type.value)
        summaries.append(f"{posture_label} 행동이 {len(group_events)}번 확인됐어요.")
    return summaries


def _format_duration(total_seconds: float) -> str:
    """초 단위를 자연스러운 한글 표현으로. 데모 축소값(몇~몇십 초)과 실제
    운영값(몇 시간)을 같은 함수로 다 처리하려고 시/분/초 중 있는 단위만 쓴다."""
    total = int(round(total_seconds))
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours > 0:
        return f"{hours}시간 {minutes}분"
    if minutes > 0:
        return f"{minutes}분 {seconds}초"
    return f"{seconds}초"


def _build_cumulative_narrative(cumulative_forward_bend_sec: float) -> str:
    """자세유형×라벨 그룹과 무관한, 그날 하루 전체에 대한 단일 문장."""
    template = _TEMPLATES.get(EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD.value, "")
    return template.format(duration_label=_format_duration(cumulative_forward_bend_sec))
