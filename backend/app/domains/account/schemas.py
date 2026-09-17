from datetime import date, datetime, timedelta
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator


class UserRole(StrEnum):
    WIFE = "wife"
    HUSBAND = "husband"


class ProfileCompletion(StrEnum):
    MISSING = "missing"
    INCOMPLETE = "incomplete"
    COMPLETE = "complete"


class PartnerLinkStatus(StrEnum):
    UNLINKED = "unlinked"
    LINKED = "linked"


class EntryDestination(StrEnum):
    WIFE_PROFILE = "wife_profile"
    WIFE_HOME = "wife_home"
    HUSBAND_INVITATION_REQUIRED = "husband_invitation_required"
    HUSBAND_CALENDAR = "husband_calendar"


class BootstrapResponse(BaseModel):
    """FUC-B-ENTRY-001의 서버 판정 결과. 화면 경로 문자열은 Frontend가 결정한다."""

    model_config = ConfigDict(extra="forbid")

    role: UserRole
    profile: ProfileCompletion | None
    partner_link: PartnerLinkStatus
    destination: EntryDestination


class PartnerLinkResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: PartnerLinkStatus
    partner_display_name: str | None = None


class InvitationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    invitation_id: str
    invitation_url: str
    expires_at: datetime


class ProfileInput(BaseModel):
    """W-PROFILE-001~007의 최종 저장 payload. 작성 중 Step은 서버에 보존하지 않는다."""

    model_config = ConfigDict(extra="forbid")

    due_date: date | None = None
    last_period_start: date | None = None
    birth_date: date
    height_cm: float = Field(ge=100, le=250)
    pre_pregnancy_weight_kg: float = Field(ge=30, le=200)
    is_first_pregnancy: bool
    is_multiple_pregnancy: bool
    allergies: list[str] = Field(default_factory=list, max_length=30)
    medical_conditions: list[str] = Field(default_factory=list, max_length=30)
    medical_note: str = Field(default="", max_length=1000)

    @model_validator(mode="after")
    def validate_dates(self) -> "ProfileInput":
        today = date.today()
        if self.due_date is None and self.last_period_start is None:
            raise ValueError("출산예정일 또는 마지막 생리 시작일 중 하나는 필요합니다.")
        if self.last_period_start is not None and self.last_period_start > today:
            raise ValueError("마지막 생리 시작일은 미래일 수 없습니다.")
        if self.birth_date >= today:
            raise ValueError("생년월일은 오늘보다 이전이어야 합니다.")
        if self.due_date is None and self.last_period_start is not None:
            self.due_date = self.last_period_start + timedelta(days=280)
        return self


class ProfileResponse(ProfileInput):
    pregnancy_weeks: int = Field(ge=0, le=42)
    age: int = Field(ge=0)
    completed: bool = True
    updated_at: datetime
