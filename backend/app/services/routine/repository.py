"""파이프라인 B ⑦: daily_routines 1행 + routine_items N행 저장, 조회."""

from __future__ import annotations

from datetime import date
from typing import Any

import logging

from postgrest.exceptions import APIError
from supabase import Client

from app.services.routine.diff import by_item_key, carry_over, diff_items

CATEGORIES = ("meal", "household", "health", "sleep")
# S3: daily_routines는 버전별 행(revision이 가장 큰 행 = 현재), routine_items는 현재 상태(같은 행을 고쳐 씀).
ITEM_COLUMNS = ("id", "item_key", "title", "description", "payload", "status", "completed_at", "completed_by")
logger = logging.getLogger(__name__)
UNIQUE_VIOLATION = "23505"
FK_VIOLATION = "23503"


def get_routine(client: Client, user_id: str, on: date) -> dict[str, Any] | None:
    rows = (
        client.table("daily_routines")
        .select("id, date, revision, source, model, generated_at, confirmed_at, change_summary, response")
        .eq("user_id", user_id)
        .eq("date", on.isoformat())
        .order("revision", desc=True)
        .limit(1)
        .execute()
        .data
    )
    return rows[0] if rows else None


def get_edit_base(client: Client, user_id: str, on: date) -> dict[str, Any] | None:
    """S10: 그날 최신 revision + 생성 당시 입력(request_payload). 컨디션 수정 경로의 비교 기준."""
    rows = (
        client.table("daily_routines")
        .select("id, date, revision, source, model, generated_at, confirmed_at, change_summary, response, request_payload")
        .eq("user_id", user_id)
        .eq("date", on.isoformat())
        .order("revision", desc=True)
        .limit(1)
        .execute()
        .data
    )
    return rows[0] if rows else None


def has_ai_routine_before(client: Client, user_id: str, on: date, revision: int) -> bool:
    """그날 이 revision 전에 AI가 만든 루틴이 있었는가. 남편 알림 종류(오전 리포트 vs 루틴 변경) 판단용(S5)."""
    rows = (
        client.table("daily_routines")
        .select("id")
        .eq("user_id", user_id)
        .eq("date", on.isoformat())
        .eq("source", "ai")
        .lt("revision", revision)
        .limit(1)
        .execute()
        .data
    )
    return bool(rows)


def get_latest_before(client: Client, user_id: str, before: date) -> dict[str, Any] | None:
    """1차 폴백용 전일(가장 최근 과거) 루틴."""
    rows = (
        client.table("daily_routines")
        .select("date, response")
        .eq("user_id", user_id)
        .lt("date", before.isoformat())
        .order("date", desc=True)
        .order("revision", desc=True)
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


def _current_revision(client: Client, user_id: str, on: date) -> int:
    rows = (
        client.table("daily_routines")
        .select("revision")
        .eq("user_id", user_id)
        .eq("date", on.isoformat())
        .order("revision", desc=True)
        .limit(1)
        .execute()
        .data
    )
    return int(rows[0]["revision"]) if rows else 0


def _sync_items(
    client: Client, user_id: str, on: date, routine_id: str,
    old: list[dict[str, Any]], new: list[dict[str, Any]],
) -> None:
    """routine_items를 새 버전에 맞춘다. 삭제 후 재삽입하지 않는다(FK·다른 도메인 조회 보호).

    같은 키 항목은 내용(제목·설명)을 최신으로 갱신하고 완료 기록은 그대로 둔다(키 기준 유지), 새 항목은 추가,
    빠진 항목은 삭제하되 다른 테이블이 참조해 삭제가 막히면 change_kind='removed'로 남긴다.
    """
    old_by_key = by_item_key(old)
    scope = {"routine_id": routine_id, "user_id": user_id, "date": on.isoformat()}
    inserts = []
    for item in carry_over(old, new):
        previous = old_by_key.get(item["item_key"])
        if previous is None:
            inserts.append({**item, **scope})
            continue
        values = {k: v for k, v in item.items() if k not in ("item_key", "status", "completed_at", "completed_by")}
        client.table("routine_items").update({**values, "routine_id": routine_id}).eq("id", previous["id"]).execute()
    if inserts:
        client.table("routine_items").insert(inserts).execute()
    new_keys = {i["item_key"] for i in new}
    dropped = [p for key, p in old_by_key.items() if key not in new_keys]
    kept_by_feedback = _with_feedback(client, [p["id"] for p in dropped])  # K9
    for previous in dropped:
        if previous["id"] in kept_by_feedback:
            # K9: 메뉴 수락·거절 기록이 달린 항목은 지우지 않는다(recommendation_feedback가 on delete cascade).
            client.table("routine_items").update(
                {"change_kind": "removed", "routine_id": routine_id}
            ).eq("id", previous["id"]).execute()
            continue
        try:
            client.table("routine_items").delete().eq("id", previous["id"]).execute()
        except APIError as error:
            if error.code != FK_VIOLATION:
                raise
            client.table("routine_items").update(
                {"change_kind": "removed", "routine_id": routine_id}
            ).eq("id", previous["id"]).execute()


def _with_feedback(client: Client, item_ids: list[str]) -> set[str]:
    """K9: 메뉴 수락·거절 기록(Care 소유 recommendation_feedback)이 달린 항목 id. 조회 실패는 '있다'로 보수적 처리."""
    if not item_ids:
        return set()
    try:
        rows = (
            client.table("recommendation_feedback")
            .select("routine_item_id")
            .in_("routine_item_id", item_ids)
            .execute()
            .data
        )
    except APIError:
        logger.warning("피드백 조회 실패, 항목을 지우지 않고 removed로 남긴다")
        return set(item_ids)
    return {r["routine_item_id"] for r in rows}


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
    change_reason: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """새 revision 행을 넣고 routine_items를 그 버전으로 맞춘다. 첫 생성이면 change_summary는 None.

    change_reason(S10) = {"categories": 다시 만든 가이드, "conditions": 바뀐 컨디션 키} → change_summary에 합친다.
    """
    old_items = (
        client.table("routine_items").select(*ITEM_COLUMNS)
        .eq("user_id", user_id).eq("date", on.isoformat()).execute().data
    )
    new_items = to_items(response)
    row = {
        "user_id": user_id,
        "date": on.isoformat(),
        "source": source,
        "model": model,
        "prompt_version": prompt_version,
        "request_payload": request_payload,
        "response": response,
        "error_message": error_message,
        "change_summary": {**diff_items(old_items, new_items), **(change_reason or {})} if old_items else None,
    }
    # 같은 사람이 동시에 두 번 생성하면 revision이 겹친다 → 번호를 다시 받아 1번만 재시도.
    for attempt in (1, 2):
        row["revision"] = _current_revision(client, user_id, on) + 1
        try:
            saved = client.table("daily_routines").insert(row).execute().data[0]
            break
        except APIError as error:
            if error.code != UNIQUE_VIOLATION or attempt == 2:
                raise
    _sync_items(client, user_id, on, saved["id"], old_items, new_items)
    return saved
