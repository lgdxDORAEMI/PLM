"""챗봇 대화 (FUC-W-CHAT-001, W-CHAT-001). Relationship/Integration 담당(Developer B)
소유. NFR-027(대화 이력 보관·파기 기준)이 확정되기 전까지는 Stub(프로세스 메모리)만
제공한다 — 실제 AI 응답을 지어내지 않는다(BACKEND_ARCHITECTURE.md, STEP 8 참고)."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.core.security import CurrentUser, get_current_user
from app.domains.chat.schemas import ChatMessageInput, ChatMessageResponse
from app.domains.chat.service import ChatService, ChatServicePort
from app.domains.chat.stub_repository import StubChatRepository
from app.utils import dates

router = APIRouter(prefix="/chat", tags=["chat"])
_repository = StubChatRepository()


def get_chat_service() -> ChatServicePort:
    return ChatService(_repository)


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[ChatServicePort, Depends(get_chat_service)]


@router.get("/messages", response_model=list[ChatMessageResponse])
def list_messages(
    user: User,
    service: Service,
    target_date: date | None = Query(default=None, alias="date"),
) -> list[ChatMessageResponse]:
    return service.list_messages(user.id, target_date or dates.today_kst())


@router.post("/messages", response_model=ChatMessageResponse)
def send_message(
    payload: ChatMessageInput, user: User, service: Service
) -> ChatMessageResponse:
    """MVP는 식사 가이드 재조정 한정(FUC-W-CHAT-001). Stub은 실제 AI 응답을 생성하지
    않고 고정 안내 문구만 돌려준다."""
    return service.send_message(user.id, dates.today_kst(), payload)
