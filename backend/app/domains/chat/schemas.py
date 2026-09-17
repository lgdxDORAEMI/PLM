from datetime import datetime
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
    suggested_actions: list[str] | None = None
    created_at: datetime
