"""Chat 대화 이력을 실제 DB(`chat_messages`)에 연결한다.

FUC-W-CHAT-004(대화 데이터 분리 저장) 중 conversation history 저장만 담당한다.
NFR-027(보관·파기 기준)이 아직 미정이라 삭제 로직은 없다 — migration
(20260917010700)도 같은 전제로 컬럼 구조만 만들고 자동 삭제는 넣지 않았다.
정책이 정해지면 별도 migration/배치로 추가한다.

실제 AI 응답(FUC-W-CHAT-001의 자연어 재조정)은 아직 없다 — 여기서도 Stub과
동일한 고정 안내 문구를 그대로 저장한다. 대화가 사라지지 않게 하는 것과
"AI가 답한다"는 서로 다른 작업이며, 이 파일은 전자만 다룬다.
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
COLUMNS = "id,role,content,suggested_actions,created_at"

# Stub과 동일한 문구 — 실제 AI 응답이 붙기 전까지는 이 저장소도 지어내지 않는다.
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
        suggested_actions=row.get("suggested_actions"),
        created_at=created_at,
    )
