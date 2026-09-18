"""파이프라인 B: 재생성 시 이전 루틴과 비교(R2). item_key로 짝을 맞춘다.

repository.save_routine(S3)이 저장 시 호출한다. 여기 함수들은 DB를 보지 않는 순수 함수다.
비교 대상은 `repository.to_items()` 모양의 항목 dict.
"""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)

# 내용이 바뀌었는지 판단하는 필드 = 이름(메뉴·활동명)만. AI는 같은 메뉴여도 설명 문장(description·payload)을
# 매번 새로 쓰므로, 이를 비교하면 재생성마다 전부 "변경"이 된다(09-18 실DB: 7개 중 7개 updated).
# 설명·근거 문장은 비교하지 않고, 저장 시 최신 문장으로 덮어쓴다(repository._sync_items).
CONTENT_FIELDS = ("title",)
STATUS_FIELDS = ("status", "completed_at", "completed_by")


def by_item_key(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    """item_key → 항목. 같은 키가 두 번 오면 첫 번째만 남긴다(짝 맞추기가 깨지므로)."""
    result: dict[str, dict[str, Any]] = {}
    for item in items or []:
        key = item.get("item_key")
        if not key:
            continue
        if key in result:
            logger.warning("item_key 중복, 뒤 항목 버림: %s", key)
            continue
        result[key] = item
    return result


def _content(item: dict[str, Any]) -> tuple:
    return tuple(item.get(field) for field in CONTENT_FIELDS)


def diff_items(old: list[dict[str, Any]], new: list[dict[str, Any]]) -> dict[str, list[str]]:
    """{added, updated, removed, unchanged} = item_key 목록. daily_routines.change_summary 모양."""
    old_by_key, new_by_key = by_item_key(old), by_item_key(new)
    added, updated, unchanged = [], [], []
    for key, item in new_by_key.items():
        if key not in old_by_key:
            added.append(key)
        elif _content(item) != _content(old_by_key[key]):
            updated.append(key)
        else:
            unchanged.append(key)
    removed = [key for key in old_by_key if key not in new_by_key]
    return {"added": added, "updated": updated, "removed": removed, "unchanged": unchanged}


def carry_over(old: list[dict[str, Any]], new: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """완료 기록(status/completed_at/completed_by)은 item_key(끼니·부위·가사) 기준으로 이어받는다.

    AI는 같은 조건이어도 제목을 매번 바꿔 쓴다(09-18 실DB: 공통 5개 중 4개 제목 변경). 완료는 "점심을 먹었다"처럼
    슬롯 단위 사실이므로, 제목이 바뀌어도 같은 키면 유지한다. 제목 변화는 change_kind='updated'로만 알린다.
    새 항목은 미완료로 시작하고 change_kind='added'. 제목이 같으면 change_kind=None.
    """
    old_by_key = by_item_key(old)
    result = []
    for item in by_item_key(new).values():
        previous = old_by_key.get(item["item_key"])
        if previous is None:
            result.append({**item, "change_kind": "added"})
            continue
        kept = {field: previous.get(field) for field in STATUS_FIELDS if previous.get(field) is not None}
        kind = "updated" if _content(item) != _content(previous) else None
        result.append({**item, **kept, "change_kind": kind})
    return result
