"""파이프라인 B ①: 입력 모으기. 프로필 + 오늘 컨디션(+예정 활동) → 평면 facts dict.

NFR-014: 여기서 고른 키만 LLM에 전달되고 daily_routines.request_payload에 남는다. 이름·이메일·키 등은 넣지 않는다.
"""

from __future__ import annotations

import logging
from datetime import date, timedelta
from types import SimpleNamespace
from typing import Any
from uuid import UUID

from supabase import Client

from app.services.movement.events import SupabaseEventStore
from app.services.movement.report import generate_daily_report
from app.utils import dates

logger = logging.getLogger(__name__)

PROFILE_COLUMNS = (
    "due_date",
    "is_first_pregnancy",
    "is_multiple_pregnancy",
    "allergies",
    "medical_conditions",
    "medical_note",
)
CONDITION_COLUMNS = (
    "nausea",
    "waist_pain",
    "pelvis_pain",
    "leg_pain",
    "wrist_pain",
    "fatigue",
    "mood",
    "sleep_quality",
    "planned_activities",
)


# S6: 예정 활동 코드표. DB(`daily_conditions.planned_activities`)에는 프론트가 보낸 한글 라벨이 그대로 저장되고
# (팀원 API `PUT /care/conditions/{date}/activities`), 웬즈데이 입력 단계에서만 코드로 바꾼다.
# 가사 item_key = `household:<code>`(prompt.HOUSEHOLD_KEYS). 목록 밖 라벨(직접 입력)은 custom.
ACTIVITY_CODES = {
    "장보기": "groceries",
    "빨래": "laundry",
    "청소": "cleaning",
    "설거지": "dishes",
    "요리": "cooking",
    "쓰레기 배출": "trash",
    "침구 정리": "bedding",
    "화분 관리": "plants",
    "정리 정돈": "tidying",
}
CUSTOM_ACTIVITY = "custom"


def to_activities(values: list[str] | None) -> list[dict[str, str]]:
    """한글 라벨(또는 이미 코드) 목록 → [{code, label}]. 직접 입력은 code=custom, label=원문."""
    known = set(ACTIVITY_CODES.values())
    result = []
    for value in values or []:
        label = str(value).strip()
        if not label:
            continue
        code = ACTIVITY_CODES.get(label) or (label if label in known else CUSTOM_ACTIVITY)
        result.append({"code": code, "label": label})
    return result


# S8: 모션 부위(BodyPart) → 건강 가이드 부위 코드(prompt.HEALTH_KEYS의 health:<부위>).
MOTION_TO_HEALTH_AREA = {"trunk": "waist", "knee": "leg", "whole_body": "whole"}


def yesterday_routine(client: Client, user_id: str, today: date) -> dict[str, Any] | None:
    """어제 루틴 완료 현황. 재생성으로 빠진 항목(change_kind=removed)은 세지 않는다. 루틴이 없으면 None."""
    rows = (
        client.table("routine_items")
        .select("item_key, status, change_kind")
        .eq("user_id", user_id)
        .eq("date", (today - timedelta(days=1)).isoformat())
        .execute()
        .data
    )
    items = [r for r in rows if r.get("change_kind") != "removed"]
    if not items:
        return None
    return {
        "completed": sum(1 for r in items if r["status"] == "completed"),
        "total": len(items),
        "not_done": [r["item_key"] for r in items if r["status"] != "completed"],
    }


def yesterday_motion(client: Client, user_id: str, today: date) -> dict[str, Any] | None:
    """어제 모션 요약(숫자·부위만, NFR-014). 모션 팀 generate_daily_report()를 읽기만 한다.

    K5: 모션 요약은 UTC 하루(어제 09:00~오늘 09:00 KST) 기준. Daily 리포트(care)와 같은 수치를 쓰려고 그대로 둔다.
    이벤트가 없거나(감지 OFF 포함) 조회가 실패하면 None — 루틴 생성은 막지 않는다(NFR-017).
    """
    try:
        store = SupabaseEventStore(SimpleNamespace(client=client))
        summary = generate_daily_report(store, UUID(user_id), today - timedelta(days=1))
    except Exception as exc:  # 모션은 보강 정보. 어떤 실패든 루틴은 컨디션만으로 만든다
        logger.info("전일 모션 요약 조회 실패, motion=None: %s", type(exc).__name__)
        return None
    if not summary.aggregates and not summary.cumulative_forward_bend_sec:
        return None
    top = summary.top_burdened_body_part
    return {
        "top_burdened_area": MOTION_TO_HEALTH_AREA.get(top.value) if top else None,
        "bending_burden_events": summary.bending_burden_event_count,
        "forward_bend_min": round(summary.cumulative_forward_bend_sec / 60),
    }


def collect_yesterday(client: Client, user_id: str, today: date) -> dict[str, Any]:
    """S8(R5): facts["yesterday"]. collect_facts와 분리 — 컨디션 계약 테스트(care)가 두 테이블만 흉내 낸다."""
    return {
        "routine": yesterday_routine(client, user_id, today),
        "motion": yesterday_motion(client, user_id, today),
    }


class ProfileMissingError(Exception):
    """프로필(출산예정일)이 없어 주차를 계산할 수 없다."""


class ConditionMissingError(Exception):
    """오늘 컨디션이 아직 입력되지 않았다."""


def collect_facts(client: Client, user_id: str, today: date) -> dict[str, Any]:
    profile_rows = (
        client.table("pregnancy_profiles").select(*PROFILE_COLUMNS).eq("user_id", user_id).limit(1).execute().data
    )
    if not profile_rows or profile_rows[0].get("due_date") is None:
        raise ProfileMissingError
    profile = profile_rows[0]

    condition_rows = (
        client.table("daily_conditions")
        .select(*CONDITION_COLUMNS)
        .eq("user_id", user_id)
        .eq("date", today.isoformat())
        .limit(1)
        .execute()
        .data
    )
    if not condition_rows:
        raise ConditionMissingError
    condition = condition_rows[0]

    week, _ = dates.pregnancy_age(date.fromisoformat(str(profile["due_date"])), today)
    facts: dict[str, Any] = {"week": week, "date": today.isoformat()}
    for column in PROFILE_COLUMNS[1:]:
        facts[column] = profile.get(column)
    for column in CONDITION_COLUMNS:
        facts[column] = condition.get(column)
    facts["planned_activities"] = to_activities(condition.get("planned_activities"))
    return facts
