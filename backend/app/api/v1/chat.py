"""Authenticated chat history and contextual LLM replies.

Supabase stores the conversation. The retention policy remains undecided.
"""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.chat.schemas import (
    ChatMessageInput,
    ChatMessageResponse,
    MealAlternativeInput,
    MealAlternativeResponse,
)
from app.domains.chat.service import ChatService, ChatServicePort
from app.domains.chat.supabase_repository import SupabaseChatRepository
from app.core.config import get_settings
from app.services.supabase_service import get_supabase_service
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.retriever import KnowledgeRetriever
from app.utils import dates

router = APIRouter(prefix="/chat", tags=["chat"])

STORAGE_UNAVAILABLE = "대화 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_chat_service() -> ChatServicePort:
    try:
        client = get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error
    settings = get_settings()
    if not settings.llm_api_key.get_secret_value():
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "AI 연결 설정이 없습니다.")
    generator = OpenAIRoutineGenerator(settings)
    retriever = KnowledgeRetriever(client, generator.client)
    return ChatService(
        SupabaseChatRepository(client), client=client,
        generator=generator, retriever=retriever,
    )


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[ChatServicePort, Depends(get_chat_service)]


@router.get("/messages", response_model=list[ChatMessageResponse])
def list_messages(
    user: User,
    service: Service,
    target_date: date | None = Query(default=None, alias="date"),
) -> list[ChatMessageResponse]:
    try:
        return service.list_messages(user.id, target_date or dates.today_kst())
    except Exception as error:
        raise to_http_exception(error) from error


@router.post("/messages", response_model=ChatMessageResponse)
async def send_message(
    payload: ChatMessageInput, user: User, service: Service
) -> ChatMessageResponse:
    """Generate a contextual LLM answer, then persist both sides of the exchange."""
    try:
        return await service.send_message(user.id, dates.today_kst(), payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post("/meal-alternative", response_model=MealAlternativeResponse)
async def meal_alternative(
    payload: MealAlternativeInput, user: User, service: Service
) -> MealAlternativeResponse:
    """식사 가이드 '다른 메뉴 보기'(09-22): 조건에 맞는 새 메뉴 1개. 대화로 저장하지 않고 루틴도 바꾸지 않는다."""
    try:
        return await service.meal_alternative(user.id, dates.today_kst(), payload)
    except Exception as error:
        raise to_http_exception(error) from error
