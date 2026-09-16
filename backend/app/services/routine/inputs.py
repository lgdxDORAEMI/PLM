"""파이프라인 B ①: 입력 모으기. 프로필 + 오늘 컨디션(+예정 활동) → 평면 facts dict.

NFR-014: 여기서 고른 키만 LLM에 전달되고 daily_routines.request_payload에 남는다. 이름·이메일·키 등은 넣지 않는다.
"""

from __future__ import annotations

from datetime import date
from typing import Any

from supabase import Client

from app.utils import dates

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
    return facts
