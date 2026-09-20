"""챗봇 대화 (FUC-W-CHAT-001, W-CHAT-001). Relationship/Integration 담당(Developer B)
소유. 2026-09-20부터 대화 이력(conversation history, FUC-W-CHAT-004)은
Supabase(`chat_messages`)에 실제로 저장된다 — NFR-027(보관·파기 기준)이 아직
미정이라 삭제 로직은 없다(무기한 보관). 실제 AI 응답은 여전히 없다 — 고정
안내 문구만 저장·반환한다(BACKEND_ARCHITECTURE.md, STEP 8 참고)."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.chat.schemas import ChatMessageInput, ChatMessageResponse
from app.domains.chat.service import ChatService, ChatServicePort
from app.domains.chat.supabase_repository import SupabaseChatRepository
from app.services.supabase_service import get_supabase_service
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
    return ChatService(SupabaseChatRepository(client))


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
def send_message(
    payload: ChatMessageInput, user: User, service: Service
) -> ChatMessageResponse:
    """MVP는 식사 가이드 재조정 한정(FUC-W-CHAT-001). 실제 AI 응답을 생성하지
    않고 고정 안내 문구만 저장·반환한다."""
    try:
        return service.send_message(user.id, dates.today_kst(), payload)
    except Exception as error:
        raise to_http_exception(error) from error
