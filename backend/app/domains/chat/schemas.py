from datetime import datetime
from typing import Any
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class ChatRole(StrEnum):
    USER = "user"
    ASSISTANT = "assistant"


class ConditionField(StrEnum):
    NAUSEA = "nausea"
    WAIST_PAIN = "waist_pain"
    PELVIS_PAIN = "pelvis_pain"
    LEG_PAIN = "leg_pain"
    WRIST_PAIN = "wrist_pain"
    FATIGUE = "fatigue"


class ConditionChange(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field: ConditionField
    value: int = Field(ge=1, le=5)


class RoutineUpdateStatus(StrEnum):
    AWAITING_CONFIRMATION = "awaiting_confirmation"
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"


class RoutineUpdateState(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_id: str
    status: RoutineUpdateStatus
    summary: str
    changes: list[ConditionChange]
    error_message: str | None = None
    routine_revision: int | None = None


class RoutineUpdateDecision(StrEnum):
    CONFIRM = "confirm"
    CANCEL = "cancel"


class RoutineUpdateDecisionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action: RoutineUpdateDecision


class ChatMessageInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(min_length=1, max_length=2000)
    routine_item_id: str | None = None


class MealAlternativeInput(BaseModel):
    """식사 가이드 '다른 메뉴 보기'(09-22). 대화가 아니라 저장하지 않는다."""

    model_config = ConfigDict(extra="forbid")

    routine_item_id: str
    request: str = Field(default="다른 메뉴 보기", min_length=1, max_length=200)


class MealAlternativeResponse(BaseModel):
    """추천 카드 1장. 모양 = 웬즈데이 meal payload. 선택은 프론트가 Care API로 직접 한다."""

    model_config = ConfigDict(extra="forbid")

    routine_item_id: str
    title: str
    reason: str
    nutritionTags: list[str]
    cautions: list[dict[str, Any]]
    imagePath: str | None = None
    imageUrl: str | None = None


class ChatMessageResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message_id: str
    role: ChatRole
    content: str
    routine_item_id: str | None = None
    suggested_actions: list[str] | None = None
    # S5 식사 모드 추천 카드 {title, reason, nutritionTags, cautions}. 선택은 사용자가 Care API로 직접 한다(S6).
    recommendation: dict[str, Any] | None = None
    # S8 컨디션 수정 확인 및 백그라운드 웬즈데이 재생성 상태. job_id는 이 assistant 메시지 id다.
    routine_update: RoutineUpdateState | None = None
    created_at: datetime
