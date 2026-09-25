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
from app.services.routine.meal_catalog import image_path_for, public_image_url
from app.services.routine.prompt import BODY_AREA_LABELS, SLEEP_ENV_LABELS

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
        health_videos = (
            self._health_videos()
            if category == RoutineCategory.HEALTH and item_rows
            else {}
        )
        meal_replacements = (
            self._meal_replacements(user_id, item_rows)
            if category == RoutineCategory.MEAL and item_rows
            else {}
        )
        items: list[GuideItem] = []
        for row in item_rows:
            # 재생성 시 FK(예: chat_messages.routine_item_id)가 삭제를 막으면 Routine AI
            # 쪽이 지우는 대신 change_kind='removed'로만 표시한다. 그 행은 화면에서 제외한다.
            if row.get("change_kind") == "removed":
                continue
            replacement = meal_replacements.get(str(row["id"]), {})
            title = replacement.get("title") or row["title"]
            payload = {**(row.get("payload") or {}), **replacement}
            payload.pop("imageAsset", None)
            image_path = image_path_for(title)
            if image_path:
                payload["imagePath"] = image_path
                image_url = public_image_url(image_path)
                if image_url:
                    payload["imageUrl"] = image_url
            items.append(
                GuideItem(
                    item_id=row["id"],
                    item_key=row["item_key"],
                    title=title,
                    description=replacement.get("reason") or row.get("description"),
                    payload=_normalize_payload(
                        category,
                        payload,
                        item_key=row["item_key"],
                        health_videos=health_videos,
                    ),
                    status=row["status"],
                    completed_by=row.get("completed_by"),
                    completed_at=row.get("completed_at"),
                )
            )
        return GuideResponse(date=target_date, category=category, items=items)

    def _meal_replacements(
        self, user_id: str, item_rows: list[dict[str, Any]]
    ) -> dict[str, dict[str, Any]]:
        """각 끼니의 최신 meal_replace를 조회 결과에만 덮는다. 원본 routine_items는 보존한다."""
        item_ids = {str(row["id"]) for row in item_rows}
        rows = self._run(
            lambda: self.client.table("recommendation_feedback")
            .select("routine_item_id", "payload", "created_at")
            .eq("user_id", user_id)
            .eq("kind", "meal_replace")
            .order("created_at", desc=True)
            .execute()
        )
        replacements: dict[str, dict[str, Any]] = {}
        for row in rows:
            item_id = str(row.get("routine_item_id"))
            payload = row.get("payload")
            if (
                item_id in item_ids
                and item_id not in replacements
                and isinstance(payload, dict)
            ):
                replacements[item_id] = payload
        return replacements

    def _health_videos(self) -> dict[str, dict[str, Any]]:
        """활성 운동 영상 카탈로그를 routine item의 부위 코드로 찾을 수 있게 만든다."""
        rows = self._run(
            lambda: self.client.table("health_exercise_videos")
            .select(
                "pain_type",
                "routine_part",
                "title_ko",
                "provider",
                "youtube_id",
                "duration",
                "target",
            )
            .eq("is_active", True)
            .execute()
        )
        return {
            row["routine_part"]: {
                "pain_type": row["pain_type"],
                "title": row["title_ko"],
                "provider": row["provider"],
                "youtube_id": row["youtube_id"],
                "url": f"https://www.youtube.com/watch?v={row['youtube_id']}",
                **({"duration": row["duration"]} if row.get("duration") else {}),
                **({"target": row["target"]} if row.get("target") else {}),
            }
            for row in rows
        }

    def _run(self, request: Callable[[], Any]) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("루틴 가이드 저장소에 연결할 수 없습니다.") from error


def _normalize_payload(
    category: RoutineCategory,
    payload: dict[str, Any],
    *,
    item_key: str = "",
    health_videos: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """09-22: 예전 루틴은 수면 환경 type이 한글("조명")로 저장돼 프론트가 5개를 모두 조명으로 처리했다.
    조회할 때 코드(light·temperature·humidity·sound·purifier)로 바꾼다. 새 루틴은 스키마가 코드만 허용한다.
    09-25: 건강 부위(bodyArea·loads[].area)는 반대로 코드로 저장하고 조회할 때 한글로 바꾼다 —
    화면에 그대로 보이는 값이라 "waist"가 노출됐다. 예전에 한글로 저장된 행은 그대로 통과한다."""
    if category == RoutineCategory.HEALTH:
        part = item_key.split(":")[1:2]
        video = (health_videos or {}).get(part[0]) if part else None
        payload = _localize_body_areas(payload)
        return {**payload, "video": video} if video else payload
    if category != RoutineCategory.SLEEP or not isinstance(payload.get("environments"), list):
        return payload
    environments = [
        {**env, "type": SLEEP_ENV_LABELS.get(str(env.get("type", "")).strip(), env.get("type"))}
        if isinstance(env, dict) else env
        for env in payload["environments"]
    ]
    return {**payload, "environments": environments}


_BODY_AREA_KO = {code: label for label, code in BODY_AREA_LABELS.items()}


def _body_area_ko(value: Any) -> Any:
    """waist → 허리. 이미 한글이거나 모르는 값이면 그대로 둔다."""
    return _BODY_AREA_KO.get(str(value).strip(), value) if value else value


def _localize_body_areas(payload: dict[str, Any]) -> dict[str, Any]:
    loads = payload.get("loads")
    if isinstance(loads, list):
        loads = [{**load, "area": _body_area_ko(load.get("area"))} if isinstance(load, dict) else load
                 for load in loads]
        payload = {**payload, "loads": loads}
    return {**payload, "bodyArea": _body_area_ko(payload.get("bodyArea"))}
