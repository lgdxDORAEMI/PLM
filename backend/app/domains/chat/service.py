import asyncio
from datetime import date
from typing import Protocol

from supabase import Client

from app.domains.errors import DomainNotFoundError
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.retriever import KnowledgeRetriever

from .context import collect_context
from .repository import ChatRepository
from .responder import generate_reply
from .schemas import ChatMessageInput, ChatMessageResponse
from .supabase_repository import SupabaseChatRepository


class ChatServicePort(Protocol):
    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]: ...

    async def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse: ...


class ChatService(ChatServicePort):
    def __init__(
        self, repository: ChatRepository, *, client: Client | None = None,
        generator: OpenAIRoutineGenerator | None = None,
        retriever: KnowledgeRetriever | None = None,
    ) -> None:
        self.repository = repository
        self.client = client
        self.generator = generator
        self.retriever = retriever

    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]:
        return self.repository.list_messages(user_id, target_date)

    async def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse:
        if self.client is None or self.generator is None or self.retriever is None:
            return self.repository.add_message(user_id, target_date, payload)
        repository = self.repository
        if not isinstance(repository, SupabaseChatRepository):
            raise TypeError("AI chat requires the Supabase chat repository")
        if payload.routine_item_id and not await asyncio.to_thread(
            repository.validate_meal_item, user_id, target_date, payload.routine_item_id
        ):
            raise DomainNotFoundError("해당 날짜의 식사 루틴을 찾을 수 없습니다.")
        context = await asyncio.to_thread(collect_context, self.client, user_id, target_date)
        history = await asyncio.to_thread(
            repository.history_for_mode, user_id, target_date, payload.routine_item_id
        )
        rules = (
            "현재 식사 메뉴에 대한 질문에는 답하되 루틴을 직접 변경하지 않는다. 추천 카드를 생성하지 않는다."
            if payload.routine_item_id else
            "일반 상담이다. 식사 메뉴 변경 요청은 식사 가이드에서 할 수 있다고 안내한다. "
            "가사·건강·수면 루틴 변경 요청은 지원하지 않는다고 안내한다."
        )
        reply = await generate_reply(
            self.generator, self.retriever, context, payload.content, history, rules
        )
        return await asyncio.to_thread(
            repository.add_ai_message, user_id, target_date, payload,
            reply.content, reply.suggested_actions,
        )
