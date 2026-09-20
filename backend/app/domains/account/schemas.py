from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict


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
