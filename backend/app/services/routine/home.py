"""홈 "이번 주에 알아두세요" 주차 안내.

사용자별·KST 날짜별 1건을 유지한다. 첫 조회에서 현재 임신 주차로 pregnancy_knowledge를
검색하고 웬즈데이가 특징 2줄·주의 1줄을 만든다. 같은 날에는 저장된 결과를 재사용한다.
RAG/LLM 생성이 실패하면 week_notes.yaml 초안을 그날의 명시적 fallback으로 저장한다.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from postgrest.exceptions import APIError
from supabase import Client

from app.services.routine.prompt import WEEK_GUIDE_PROMPT_VERSION
from app.services.routine.service import load_template
from app.utils import dates

logger = logging.getLogger(__name__)

WEEK_NOTES_PATH = Path(__file__).resolve().parent / "week_notes.yaml"
UNIQUE_VIOLATION = "23505"


@lru_cache(maxsize=1)
def load_bands() -> list[dict[str, Any]]:
    """RAG/LLM 실패 때만 쓰는 가용성 폴백. 서비스 기본 콘텐츠가 아니다."""
    return yaml.safe_load(WEEK_NOTES_PATH.read_text(encoding="utf-8"))["bands"]


def week_band(week: int) -> dict[str, Any]:
    """week가 속한 구간. 1주 미만은 첫 구간, 40주 초과는 마지막 구간."""
    bands = load_bands()
    return next((b for b in bands if b["weeks"][0] <= week <= b["weeks"][1]), bands[0] if week < 1 else bands[-1])


def get_daily_guide(client: Client, user_id: str, on: date) -> dict[str, Any] | None:
    rows = (
        client.table("home_week_guides")
        .select("pregnancy_week, week_notes, caution, source, source_ids, sources, model, prompt_version, generated_at")
        .eq("user_id", user_id)
        .eq("guide_date", on.isoformat())
        .limit(1)
        .execute()
        .data
    )
    return rows[0] if rows else None


def _validate_generated(generated: dict[str, Any], chunks: list[dict[str, Any]]) -> dict[str, Any]:
    """화면 모양과 RAG 출처를 함께 검증한다. 출처 없는 LLM 문장은 성공으로 저장하지 않는다."""
    notes = [str(value).strip() for value in generated.get("week_notes") or []]
    caution = str(generated.get("caution") or "").strip()
    if len(notes) != 2 or not all(notes) or not caution:
        raise ValueError("주차 안내 문장 형식이 올바르지 않습니다.")

    by_id = {int(chunk["id"]): chunk for chunk in chunks}
    source_ids = list(dict.fromkeys(
        int(value) for value in generated.get("source_ids") or [] if int(value) in by_id
    ))
    if not source_ids:
        raise ValueError("주차 안내에 유효한 RAG 출처가 없습니다.")
    sources = [{"id": source_id, "source": str(by_id[source_id].get("source") or "")} for source_id in source_ids]
    return {"week_notes": notes, "caution": caution, "source_ids": source_ids, "sources": sources}


def _fallback(week: int) -> dict[str, Any]:
    band = week_band(week)
    return {
        "week_notes": list(band["notes"]),
        "caution": band["caution"],
        "source_ids": [],
        "sources": [],
    }


def _save_daily_guide(
    client: Client,
    user_id: str,
    on: date,
    week: int,
    guide: dict[str, Any],
    *,
    source: str,
    model: str | None,
    replace: bool = False,
) -> dict[str, Any]:
    payload = {
        "user_id": user_id,
        "guide_date": on.isoformat(),
        "pregnancy_week": week,
        "week_notes": guide["week_notes"],
        "caution": guide["caution"],
        "source": source,
        "source_ids": guide["source_ids"],
        "sources": guide["sources"],
        "model": model,
        "prompt_version": WEEK_GUIDE_PROMPT_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    if replace:
        rows = (
            client.table("home_week_guides")
            .update(payload)
            .eq("user_id", user_id)
            .eq("guide_date", on.isoformat())
            .execute()
            .data
        )
        if rows:
            return rows[0]
    try:
        return client.table("home_week_guides").insert(payload).execute().data[0]
    except APIError as error:
        if error.code != UNIQUE_VIOLATION:
            raise
        # 같은 사용자의 홈 요청이 동시에 들어오면 먼저 저장된 하루 1건을 사용한다.
        cached = get_daily_guide(client, user_id, on)
        if cached is None:
            raise
        return cached


async def resolve_daily_guide(
    client: Client,
    retriever: Any,
    generator: Any,
    user_id: str,
    on: date,
    week: int | None,
    model: str,
) -> dict[str, Any] | None:
    """캐시가 있으면 OpenAI를 호출하지 않고, 없을 때만 RAG·LLM을 각각 1회 호출한다."""
    if week is None:
        return None
    cached = get_daily_guide(client, user_id, on)
    if cached is not None and int(cached["pregnancy_week"]) == week:
        return cached

    try:
        chunks = await retriever.search_week_guide(week)
        if not chunks:
            raise ValueError("주차 안내 RAG 검색 결과가 없습니다.")
        generated = await generator.generate_week_guide(week, chunks)
        guide = _validate_generated(generated, chunks)
        source, used_model = "rag", model
    except Exception as exc:
        logger.warning("홈 주차 안내 생성 실패, 하루 폴백 저장: %s", f"{type(exc).__name__}: {exc}"[:200])
        guide = _fallback(week)
        source, used_model = "fallback", None
    return _save_daily_guide(
        client, user_id, on, week, guide, source=source, model=used_model,
        replace=cached is not None,
    )


def home_block(week: int | None, guide: dict[str, Any] | None) -> dict[str, Any]:
    """기존 문자열 계약을 유지하면서 생성 근거와 생성 상태를 함께 반환한다."""
    summaries = dict(load_template()["summaries"])
    if week is None or guide is None:
        return {
            "week": None,
            "week_notes": [],
            "caution": None,
            "summaries": summaries,
            "source": None,
            "source_ids": [],
            "sources": [],
            "generated_at": None,
        }
    return {
        "week": week,
        "week_notes": list(guide["week_notes"]),
        "caution": guide["caution"],
        "summaries": summaries,
        "source": guide.get("source"),
        "source_ids": list(guide.get("source_ids") or []),
        "sources": list(guide.get("sources") or []),
        "generated_at": guide.get("generated_at"),
    }


def current_week(client: Client, user_id: str, on: date) -> int | None:
    rows = client.table("pregnancy_profiles").select("due_date").eq("user_id", user_id).limit(1).execute().data
    if not rows or not rows[0].get("due_date"):
        return None
    week, _ = dates.pregnancy_age(date.fromisoformat(str(rows[0]["due_date"])), on)
    return week
