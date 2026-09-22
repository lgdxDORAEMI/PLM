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

from app.domains.errors import DomainStorageError

from .repository import ChatRepository
from .schemas import ChatMessageInput, ChatMessageResponse, ChatRole

TABLE = "chat_messages"
COLUMNS = "id,role,content,routine_item_id,suggested_actions,created_at"

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

    def history_for_mode(self, user_id: str, target_date: date, routine_item_id: str | None) -> list[dict[str, str]]:
        """Only recent messages from the same day and conversation mode reach the LLM."""
        rows = self.list_messages(user_id, target_date)
        return [
            {"role": row.role.value, "content": row.content}
            for row in rows if row.routine_item_id == routine_item_id
        ][-6:]

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
        content: str, actions: list[str],
    ) -> ChatMessageResponse:
        """Persist the user's text and the generated assistant reply for this mode."""
        base = {"user_id": user_id, "date": target_date.isoformat(), "routine_item_id": payload.routine_item_id}
        self._run(lambda: self.client.table(TABLE).insert({**base, "role": ChatRole.USER.value, "content": payload.content}).execute())
        rows = self._run(
            lambda: self.client.table(TABLE).insert({
                **base, "role": ChatRole.ASSISTANT.value, "content": content,
                "suggested_actions": actions,
            }).execute()
        )
        return _to_response(rows[0])

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
        created_at=created_at,
    )
