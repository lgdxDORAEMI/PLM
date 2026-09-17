from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

from .schemas import PartnerLinkStatus, ProfileCompletion, ProfileResponse, UserRole


@dataclass(frozen=True)
class AccountState:
    role: UserRole
    profile: ProfileCompletion | None
    partner_link: PartnerLinkStatus
    partner_display_name: str | None = None


@dataclass(frozen=True)
class InvitationRecord:
    invitation_id: str
    token: str
    wife_user_id: str
    expires_at: datetime


class AccountRepository(Protocol):
    """Supabase adapter가 구현해야 할 Account 저장 계약."""

    def get_state(self, user_id: str) -> AccountState: ...

    def create_invitation(
        self, user_id: str, *, expires_at: datetime
    ) -> InvitationRecord: ...

    def get_profile(self, user_id: str) -> ProfileResponse | None: ...

    def save_profile(self, user_id: str, profile: ProfileResponse) -> ProfileResponse: ...
