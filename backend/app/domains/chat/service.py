from datetime import date
from typing import Protocol

from .repository import ChatRepository
from .schemas import ChatMessageInput, ChatMessageResponse


class ChatServicePort(Protocol):
    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]: ...

    def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse: ...


class ChatService(ChatServicePort):
    def __init__(self, repository: ChatRepository) -> None:
        self.repository = repository

    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]:
        return self.repository.list_messages(user_id, target_date)

    def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse:
        return self.repository.add_message(user_id, target_date, payload)
