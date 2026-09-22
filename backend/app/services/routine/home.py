"""홈 웰컴 카드 ① 주차 특징 블록(FUC-W-HOME-001 ①). GET/POST /routine/today 응답의 `home`.

주차별 고정 문구(week_notes.yaml)는 AI가 판단하지 않는다. 주의 문구는 오늘의 팁(AI, 루틴 response.tip)이 있으면
팁을, 없으면(폴백 등) 주차별 기본 문구를 쓴다. summaries = 4종 카드 한 줄 요약(09-22, 없으면 템플릿 문구).
이름·컨디션 한 줄은 이 블록에 아직 없다(별도 결정).
"""

from __future__ import annotations

from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from supabase import Client

from app.services.routine.service import fill_summaries
from app.utils import dates

WEEK_NOTES_PATH = Path(__file__).resolve().parent / "week_notes.yaml"


@lru_cache(maxsize=1)
def load_bands() -> list[dict[str, Any]]:
    return yaml.safe_load(WEEK_NOTES_PATH.read_text(encoding="utf-8"))["bands"]


def week_band(week: int) -> dict[str, Any]:
    """week가 속한 구간. 1주 미만은 첫 구간, 40주 초과는 마지막 구간."""
    bands = load_bands()
    return next((b for b in bands if b["weeks"][0] <= week <= b["weeks"][1]), bands[0] if week < 1 else bands[-1])


def home_block(week: int | None, routine_response: dict[str, Any] | None) -> dict[str, Any]:
    """{week, week_notes, caution, summaries}. 주차를 모르면(프로필 없음) week_notes 빈 목록·caution None."""
    summaries = fill_summaries((routine_response or {}).get("summaries"))  # 09-22 전에 저장된 루틴은 템플릿 문구
    if week is None:
        return {"week": None, "week_notes": [], "caution": None, "summaries": summaries}
    band = week_band(week)
    tip = ((routine_response or {}).get("tip") or {}).get("text")
    return {"week": week, "week_notes": list(band["notes"]), "caution": tip or band["caution"], "summaries": summaries}


def current_week(client: Client, user_id: str, on: date) -> int | None:
    rows = client.table("pregnancy_profiles").select("due_date").eq("user_id", user_id).limit(1).execute().data
    if not rows or not rows[0].get("due_date"):
        return None
    week, _ = dates.pregnancy_age(date.fromisoformat(str(rows[0]["due_date"])), on)
    return week
