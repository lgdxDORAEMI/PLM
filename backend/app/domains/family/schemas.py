from datetime import date, datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field


class HouseholdItemStatus(StrEnum):
    UNCONFIRMED = "unconfirmed"
    CONFIRMED = "confirmed"
    COMPLETED = "completed"


class HouseholdRequestStatus(StrEnum):
    UNCONFIRMED = "unconfirmed"
    CONFIRMED = "confirmed"
    COMPLETED = "completed"


class HouseholdRequestItemInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=100)
    helper_info: str | None = Field(default=None, max_length=500)
    routine_item_id: str | None = None


class HouseholdRequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_date: date
    reason: str = Field(min_length=1, max_length=300)
    items: list[HouseholdRequestItemInput] = Field(min_length=1, max_length=20)


class HouseholdRequestItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    item_id: str
    title: str
    helper_info: str | None = None
    routine_item_id: str | None = None
    status: HouseholdItemStatus


class HouseholdRequestResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    target_date: date
    requester_display_name: str
    recipient_display_name: str
    reason: str
    status: HouseholdRequestStatus
    items: list[HouseholdRequestItem]
    requested_at: datetime
    confirmed_at: datetime | None = None
    completed_at: datetime | None = None


class NotificationType(StrEnum):
    MORNING_REPORT = "morning_report"
    HOUSEHOLD_REQUEST = "household_request"
    CONDITION_CHANGED = "condition_changed"


class NotificationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    notification_id: str
    type: NotificationType
    title: str
    body: str
    target_date: date | None = None
    reference_id: str
    created_at: datetime
    read_at: datetime | None = None


class MorningReportResponse(BaseModel):
    """남편에게 허용된 요약만 담고 Profile 원본과 AI 대화는 포함하지 않는다."""

    model_config = ConfigDict(extra="forbid")

    target_date: date
    pregnancy_week: int = Field(ge=0, le=42)
    condition_summary: list[str]
    planned_activities: list[str]
    guide_summaries: dict[str, str]


class MotionCollectionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    enabled: bool


class MotionPrivacyResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    consent_granted: bool
    collection_enabled: bool
    updated_at: datetime
