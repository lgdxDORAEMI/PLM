"""Authenticated chat history and contextual LLM replies.

Supabase stores the conversation. The retention policy remains undecided.
"""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status

from app.api.v1.care import get_care_service
from app.api.v1.domain_errors import to_http_exception
from app.api.v1.family import get_family_service
from app.api.v1.routine import generate_today_and_notify, get_routine_service
from app.core.security import CurrentUser, get_current_user
from app.domains.care.service import CareServicePort
from app.domains.chat.schemas import (
    ChatMessageInput,
    ChatMessageResponse,
    MealAlternativeInput,
    MealAlternativeResponse,
    RoutineUpdateDecisionInput,
    RoutineUpdateState,
)
from app.domains.chat.service import ChatService, ChatServicePort
from app.domains.chat.supabase_repository import SupabaseChatRepository
from app.domains.family.service import FamilyServicePort
from app.core.config import get_settings
from app.services.supabase_service import get_supabase_service
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.retriever import KnowledgeRetriever
from app.services.routine.service import RoutineService
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
Care = Annotated[CareServicePort, Depends(get_care_service)]
Routine = Annotated[RoutineService, Depends(get_routine_service)]
Family = Annotated[FamilyServicePort, Depends(get_family_service)]


@router.get("/messages", response_model=list[ChatMessageResponse])
def list_messages(
    user: User,
    service: Service,
    target_date: date | None = Query(default=None, alias="date"),
) -> list[ChatMessageResponse]:
    try:
        return service.list_messages(user.id, target_date)
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


@router.get(
    "/messages/{message_id}/routine-update", response_model=RoutineUpdateState
)
def routine_update_status(
    message_id: str, user: User, service: Service
) -> RoutineUpdateState:
    try:
        return service.get_routine_update(user.id, dates.today_kst(), message_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/messages/{message_id}/routine-update",
    response_model=RoutineUpdateState,
    status_code=status.HTTP_202_ACCEPTED,
)
async def decide_routine_update(
    message_id: str,
    payload: RoutineUpdateDecisionInput,
    background_tasks: BackgroundTasks,
    user: User,
    service: Service,
    care: Care,
    routine: Routine,
    family: Family,
) -> RoutineUpdateState:
    """확인 즉시 반환한다. 컨디션 저장·웬즈데이 재생성은 응답 뒤 실행한다."""
    today = dates.today_kst()
    try:
        state, should_start = service.decide_routine_update(
            user.id, today, message_id, payload.action
        )
        if should_start:
            async def regenerate() -> dict:
                return await generate_today_and_notify(user.id, today, routine, family)

            background_tasks.add_task(
                service.run_routine_update,
                user.id,
                today,
                message_id,
                care,
                regenerate,
            )
        return state
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
