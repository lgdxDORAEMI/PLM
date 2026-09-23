"""Chat 대화 이력을 실제 DB(`chat_messages`)에 연결한다.

FUC-W-CHAT-004(대화 데이터 분리 저장) 중 conversation history 저장만 담당한다.
NFR-027(보관·파기 기준)이 아직 미정이라 삭제 로직은 없다 — migration
(20260917010700)도 같은 전제로 컬럼 구조만 만들고 자동 삭제는 넣지 않았다.
정책이 정해지면 별도 migration/배치로 추가한다.

실제 요청에서는 생성된 AI 답변을 저장한다. 기존 add_message는 Stub 계약
검증용으로 유지하고 제품 API에서는 사용하지 않는다.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Callable

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainNotFoundError, DomainStorageError

from .repository import ChatRepository
from .responder import HISTORY_LIMIT
from .schemas import (
    ChatMessageInput,
    ChatMessageResponse,
    ChatRole,
    RoutineUpdateState,
    RoutineUpdateStatus,
)

TABLE = "chat_messages"
COLUMNS = "id,role,content,routine_item_id,suggested_actions,recommendation,routine_update,created_at"

# Legacy Stub response retained for isolated contract tests; product requests use add_ai_message.
PLACEHOLDER_REPLY = "아직 실제 AI 응답 기능은 준비 중이에요. 곧 연결할게요."


class SupabaseChatRepository(ChatRepository):
    def __init__(self, client: Client) -> None:
        self.client = client

    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]:
        rows = self._run(
            lambda: self.client.table(TABLE)
            .select(COLUMNS)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .order("created_at")
            .execute()
        )
        return [_to_response(row) for row in rows]

    def history_for_day(self, user_id: str, target_date: date) -> list[dict[str, str]]:
        """LLM에 넘기는 이력: 같은 날짜 대화 전체(모드 무관) 최근 20개. 추천 카드는 메뉴명만 붙여 반복 추천을 막는다."""
        return [
            {
                "role": row.role.value,
                "content": row.content + (f" [추천: {row.recommendation['title']}]" if row.recommendation else ""),
            }
            for row in self.list_messages(user_id, target_date)
        ][-HISTORY_LIMIT:]

    def validate_meal_item(self, user_id: str, target_date: date, item_id: str) -> bool:
        rows = self._run(
            lambda: self.client.table("routine_items")
            .select("id")
            .eq("id", item_id)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .eq("category", "meal")
            .limit(1)
            .execute()
        )
        return bool(rows)

    def add_ai_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput,
        content: str, actions: list[str], recommendation: dict | None = None,
        routine_update: dict | None = None,
    ) -> ChatMessageResponse:
        """Persist the user's text and the generated assistant reply for this mode."""
        base = {"user_id": user_id, "date": target_date.isoformat(), "routine_item_id": payload.routine_item_id}
        self._run(lambda: self.client.table(TABLE).insert({**base, "role": ChatRole.USER.value, "content": payload.content}).execute())
        rows = self._run(
            lambda: self.client.table(TABLE).insert({
                **base, "role": ChatRole.ASSISTANT.value, "content": content,
                "suggested_actions": actions,
                # 카드가 있을 때만 칸을 쓴다 → migration 적용 전에도 일반 대화 저장은 깨지지 않는다.
                **({"recommendation": recommendation} if recommendation else {}),
                **({"routine_update": {
                    "status": RoutineUpdateStatus.AWAITING_CONFIRMATION.value,
                    **routine_update,
                }} if routine_update else {}),
            }).execute()
        )
        return _to_response(rows[0])

    def get_routine_update(
        self, user_id: str, target_date: date, message_id: str
    ) -> RoutineUpdateState:
        rows = self._run(
            lambda: self.client.table(TABLE).select(COLUMNS)
            .eq("id", message_id).eq("user_id", user_id)
            .eq("date", target_date.isoformat()).eq("role", ChatRole.ASSISTANT.value)
            .limit(1).execute()
        )
        if not rows or not rows[0].get("routine_update"):
            raise DomainNotFoundError("컨디션 수정 작업을 찾을 수 없습니다.")
        return _to_routine_update(rows[0])

    def set_routine_update_status(
        self, user_id: str, target_date: date, message_id: str,
        status: RoutineUpdateStatus, *, error_message: str | None = None,
        routine_revision: int | None = None,
    ) -> RoutineUpdateState:
        current = self.get_routine_update(user_id, target_date, message_id)
        value = current.model_dump(mode="json", exclude={"job_id"}, exclude_none=True)
        value["status"] = status.value
        if error_message is not None:
            value["error_message"] = error_message
        elif status != RoutineUpdateStatus.FAILED:
            value.pop("error_message", None)
        if routine_revision is not None:
            value["routine_revision"] = routine_revision
        rows = self._run(
            lambda: self.client.table(TABLE).update({"routine_update": value})
            .eq("id", message_id).eq("user_id", user_id)
            .eq("date", target_date.isoformat()).execute()
        )
        if not rows:
            raise DomainNotFoundError("컨디션 수정 작업을 찾을 수 없습니다.")
        return _to_routine_update(rows[0])

    def add_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse:
        self._run(
            lambda: self.client.table(TABLE)
            .insert(
                {
                    "user_id": user_id,
                    "date": target_date.isoformat(),
                    "routine_item_id": payload.routine_item_id,
                    "role": ChatRole.USER.value,
                    "content": payload.content,
                }
            )
            .execute()
        )
        rows = self._run(
            lambda: self.client.table(TABLE)
            .insert(
                {
                    "user_id": user_id,
                    "date": target_date.isoformat(),
                    "routine_item_id": payload.routine_item_id,
                    "role": ChatRole.ASSISTANT.value,
                    "content": PLACEHOLDER_REPLY,
                }
            )
            .execute()
        )
        return _to_response(rows[0])

    def _run(self, request: Callable[[], Any]) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("대화 저장소에 연결할 수 없습니다.") from error


def _to_response(row: dict) -> ChatMessageResponse:
    created_at = row["created_at"]
    if not isinstance(created_at, datetime):
        created_at = datetime.fromisoformat(str(created_at).replace("Z", "+00:00"))
    return ChatMessageResponse(
        message_id=row["id"],
        role=ChatRole(row["role"]),
        content=row["content"],
        routine_item_id=row.get("routine_item_id"),
        suggested_actions=row.get("suggested_actions"),
        recommendation=row.get("recommendation"),
        routine_update=_to_routine_update(row) if row.get("routine_update") else None,
        created_at=created_at,
    )


def _to_routine_update(row: dict) -> RoutineUpdateState:
    return RoutineUpdateState(job_id=str(row["id"]), **row["routine_update"])
