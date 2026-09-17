from datetime import date
from typing import Protocol

from .schemas import ChatMessageInput, ChatMessageResponse


class ChatRepository(Protocol):
    """Supabase adapter가 구현해야 할 Chat 저장 계약(FUC-W-CHAT-001)."""

    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]: ...

    def add_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse: ...
