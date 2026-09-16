"""파이프라인 B ⑦: daily_routines 1행 + routine_items N행 저장, 조회."""

from __future__ import annotations

from datetime import date
from typing import Any

from supabase import Client

CATEGORIES = ("meal", "household", "health", "sleep")


def get_routine(client: Client, user_id: str, on: date) -> dict[str, Any] | None:
    rows = (
        client.table("daily_routines")
        .select("id, date, source, model, generated_at, response")
        .eq("user_id", user_id)
        .eq("date", on.isoformat())
        .limit(1)
        .execute()
        .data
    )
    return rows[0] if rows else None


def get_latest_before(client: Client, user_id: str, before: date) -> dict[str, Any] | None:
    """1차 폴백용 전일(가장 최근 과거) 루틴."""
    rows = (
        client.table("daily_routines")
        .select("date, response")
        .eq("user_id", user_id)
        .lt("date", before.isoformat())
        .order("date", desc=True)
        .limit(1)
        .execute()
        .data
    )
    return rows[0] if rows else None


def to_items(routine: dict[str, Any]) -> list[dict[str, Any]]:
    """4종 응답 → routine_items 행 목록(routine_id·user_id·date 제외)."""
    items: list[dict[str, Any]] = []
    for category in CATEGORIES:
        entries = routine.get(category) or []
        if isinstance(entries, dict):  # sleep은 단일 객체
            entries = [entries]
        for order, entry in enumerate(entries):
            payload = entry.get("payload") or {}
            items.append(
                {
                    "category": category,
                    "item_key": entry.get("item_key") or f"{category}:{order}",
                    "title": entry.get("title") or "",
                    "description": payload.get("reason"),
                    "payload": payload,
                    "source_ids": [int(i) for i in entry.get("source_ids") or []],
                    "sort_order": order,
                }
            )
    return items


def save_routine(
    client: Client,
    user_id: str,
    on: date,
    *,
    source: str,
    response: dict[str, Any],
    model: str | None,
    prompt_version: str | None,
    request_payload: dict[str, Any] | None,
    error_message: str | None,
) -> dict[str, Any]:
    row = {
        "user_id": user_id,
        "date": on.isoformat(),
        "source": source,
        "model": model,
        "prompt_version": prompt_version,
        "request_payload": request_payload,
        "response": response,
        "error_message": error_message,
    }
    saved = client.table("daily_routines").upsert(row, on_conflict="user_id,date").execute().data[0]
    routine_id = saved["id"]
    # 재생성 시 이전 항목은 지우고 다시 넣는다(완료 체크는 W-RECORD-001에서 당일 재생성 정책과 함께 다룬다).
    client.table("routine_items").delete().eq("routine_id", routine_id).execute()
    items = [
        {**item, "routine_id": routine_id, "user_id": user_id, "date": on.isoformat()}
        for item in to_items(response)
    ]
    if items:
        client.table("routine_items").insert(items).execute()
    return saved
