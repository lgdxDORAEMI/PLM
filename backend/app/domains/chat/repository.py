from datetime import date
from typing import Protocol

from .schemas import ChatMessageInput, ChatMessageResponse, RoutineUpdateState, RoutineUpdateStatus


class ChatRepository(Protocol):
    """Supabase adapter가 구현해야 할 Chat 저장 계약(FUC-W-CHAT-001)."""

    def list_messages(
        self, user_id: str, target_date: date | None
    ) -> list[ChatMessageResponse]: ...

    def add_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse: ...

    def get_routine_update(
        self, user_id: str, target_date: date, message_id: str
    ) -> RoutineUpdateState: ...

    def set_routine_update_status(
        self, user_id: str, target_date: date, message_id: str,
        status: RoutineUpdateStatus, *, error_message: str | None = None,
        routine_revision: int | None = None,
    ) -> RoutineUpdateState: ...
