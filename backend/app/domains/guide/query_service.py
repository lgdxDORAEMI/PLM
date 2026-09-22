"""Meal/Household/Health/Sleep 화면용 Query Layer (STEP 11).

    Routine AI(app/services/routine/**, Routine AI 담당 소유)
        ↓ (이미 씀)
    routine_items / daily_routines (Routine AI 소유 테이블, 이 서비스는 읽기만)
        ↓
    GuideQueryService (이 파일)
        ↓
    Meal / Household / Health / Sleep API (app/api/v1/guide.py)

카테고리별로 AI를 다시 호출하지 않는다 — routine_items에 이미 저장된 행만 읽는다.
아내 화면 DB 스키마가 Meal/Household/Health/Sleep 테이블을 각각 제시하더라도,
그 데이터는 전부 routine_items(category로 구분)로 이미 표현 가능해 새 테이블을
만들지 않는다(DATA_OWNERSHIP.md Duplicate Storage 항목 2와 동일 원칙).

실행 상태(status/completed_by)는 AI가 처음 만든 daily_routines.response 스냅샷이
아니라 routine_items 원본에서 읽는다 — 완료 체크(STEP 8의 execution API)가 반영된
최신 상태를 보여주기 위해서다.
"""

from __future__ import annotations

from datetime import date
from typing import Any, Callable

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainNotFoundError, DomainStorageError
from app.services.routine.prompt import SLEEP_ENV_LABELS

from .schemas import GuideItem, GuideResponse, RoutineCategory

ITEM_COLUMNS = (
    "id",
    "item_key",
    "title",
    "description",
    "payload",
    "status",
    "completed_by",
    "completed_at",
    "change_kind",
)


class GuideQueryService:
    def __init__(self, client: Client) -> None:
        self.client = client

    def get_guide(
        self, user_id: str, target_date: date, category: RoutineCategory
    ) -> GuideResponse:
        # 1) 오늘 루틴 자체가 있는지 먼저 확인한다 — routine.py의 GET /routine/today와
        #    같은 전제(없으면 404, 앱은 컨디션 CTA를 보여준다).
        routine_rows = self._run(
            lambda: self.client.table("daily_routines")
            .select("id")
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .limit(1)
            .execute()
        )
        if not routine_rows:
            raise DomainNotFoundError("오늘 생성된 루틴이 없습니다.")

        # 2) 이 카테고리의 항목은 있을 수도 없을 수도 있다(예: 해당 없음) — 빈 목록도
        #    정상 상태이지 오류가 아니다. 루틴 자체가 없는 것과 구분한다.
        item_rows = self._run(
            lambda: self.client.table("routine_items")
            .select(*ITEM_COLUMNS)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .eq("category", category.value)
            .order("sort_order")
            .execute()
        )
        items = [
            GuideItem(
                item_id=row["id"],
                item_key=row["item_key"],
                title=row["title"],
                description=row.get("description"),
                payload=_normalize_payload(category, row.get("payload") or {}),
                status=row["status"],
                completed_by=row.get("completed_by"),
                completed_at=row.get("completed_at"),
            )
            for row in item_rows
            # 재생성 시 FK(예: chat_messages.routine_item_id)가 삭제를 막으면 Routine AI
            # 쪽이 지우는 대신 change_kind='removed'로만 표시한다(routine/repository.py
            # _sync_items) — 그 행은 더 이상 오늘 루틴이 아니므로 화면에 보여주지 않는다.
            # SQL .neq()는 NULL(대부분의 정상 행)까지 걸러내므로 Python에서 비교한다
            # (Routine AI 쪽 inputs.py가 같은 이유로 쓰는 것과 동일한 패턴).
            if row.get("change_kind") != "removed"
        ]
        return GuideResponse(date=target_date, category=category, items=items)

    def _run(self, request: Callable[[], Any]) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("루틴 가이드 저장소에 연결할 수 없습니다.") from error


def _normalize_payload(category: RoutineCategory, payload: dict[str, Any]) -> dict[str, Any]:
    """09-22: 예전 루틴은 수면 환경 type이 한글("조명")로 저장돼 프론트가 5개를 모두 조명으로 처리했다.
    조회할 때 코드(light·temperature·humidity·sound·purifier)로 바꾼다. 새 루틴은 스키마가 코드만 허용한다."""
    if category != RoutineCategory.SLEEP or not isinstance(payload.get("environments"), list):
        return payload
    environments = [
        {**env, "type": SLEEP_ENV_LABELS.get(str(env.get("type", "")).strip(), env.get("type"))}
        if isinstance(env, dict) else env
        for env in payload["environments"]
    ]
    return {**payload, "environments": environments}
