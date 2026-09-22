from datetime import datetime
from typing import Any
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class ChatRole(StrEnum):
    USER = "user"
    ASSISTANT = "assistant"


class ChatMessageInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(min_length=1, max_length=2000)
    routine_item_id: str | None = None


class ChatMessageResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message_id: str
    role: ChatRole
    content: str
    routine_item_id: str | None = None
    suggested_actions: list[str] | None = None
    # S5 식사 모드 추천 카드 {title, reason, nutritionTags, cautions}. 선택은 사용자가 Care API로 직접 한다(S6).
    recommendation: dict[str, Any] | None = None
    created_at: datetime
