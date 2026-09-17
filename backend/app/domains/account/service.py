from datetime import date, datetime, timedelta, timezone
from typing import Protocol

from app.domains.errors import (
    DomainConflictError,
    DomainForbiddenError,
    DomainNotFoundError,
)

from .repository import AccountRepository
from .schemas import (
    BootstrapResponse,
    EntryDestination,
    InvitationResponse,
    PartnerLinkResponse,
    PartnerLinkStatus,
    ProfileCompletion,
    ProfileInput,
    ProfileResponse,
    UserRole,
)


class AccountServicePort(Protocol):
    def bootstrap(self, user_id: str) -> BootstrapResponse: ...

    def partner_link(self, user_id: str) -> PartnerLinkResponse: ...

    def issue_invitation(self, user_id: str) -> InvitationResponse: ...

    def accept_invitation(self, husband_user_id: str, token: str) -> PartnerLinkResponse: ...

    def get_profile(self, user_id: str) -> ProfileResponse: ...

    def save_profile(self, user_id: str, payload: ProfileInput) -> ProfileResponse: ...


class AccountService(AccountServicePort):
    INVITATION_TTL = timedelta(hours=72)

    def __init__(self, repository: AccountRepository) -> None:
        self.repository = repository

    def bootstrap(self, user_id: str) -> BootstrapResponse:
        state = self.repository.get_state(user_id)
        destination = self._destination(state.role, state.profile, state.partner_link)
        return BootstrapResponse(
            role=state.role,
            profile=state.profile,
            partner_link=state.partner_link,
            destination=destination,
        )

    def partner_link(self, user_id: str) -> PartnerLinkResponse:
        state = self.repository.get_state(user_id)
        return PartnerLinkResponse(
            status=state.partner_link,
            partner_display_name=state.partner_display_name,
        )

    def issue_invitation(self, user_id: str) -> InvitationResponse:
        state = self.repository.get_state(user_id)
        if state.role != UserRole.WIFE:
            raise DomainForbiddenError("아내 계정만 남편 초대 링크를 발급할 수 있습니다.")
        if state.profile != ProfileCompletion.COMPLETE:
            raise DomainConflictError("프로필 최종 저장 후 남편을 초대할 수 있습니다.")
        if state.partner_link == PartnerLinkStatus.LINKED:
            raise DomainForbiddenError("이미 연동된 계정은 초대 링크를 발급할 수 없습니다.")
        expires_at = datetime.now(timezone.utc) + self.INVITATION_TTL
        record = self.repository.create_invitation(user_id, expires_at=expires_at)
        return InvitationResponse(
            invitation_id=record.invitation_id,
            invitation_url=f"/partner/join?token={record.token}",
            expires_at=record.expires_at,
        )

    def accept_invitation(self, husband_user_id: str, token: str) -> PartnerLinkResponse:
        """FUC-H-INVITE-001: 화면·인증 복귀 계약은 아직 미확정(TBD, DOMAIN_OWNERSHIP.md)
        — 여기서는 토큰 검증·연동 계약만 먼저 구현한다."""
        invitation = self.repository.find_invitation_by_token(token)
        if invitation is None:
            raise DomainNotFoundError("초대 링크를 찾을 수 없습니다.")
        now = datetime.now(timezone.utc)
        if invitation.used_at is not None or invitation.expires_at < now:
            raise DomainConflictError("만료되었거나 이미 사용된 초대 링크입니다.")
        self.repository.mark_invitation_used(invitation.invitation_id, used_at=now)
        self.repository.link_partner(invitation.wife_user_id, husband_user_id)
        # 남편 표시 이름은 Stub이 모르는 값이라 지어내지 않는다.
        return PartnerLinkResponse(status=PartnerLinkStatus.LINKED, partner_display_name=None)

    def get_profile(self, user_id: str) -> ProfileResponse:
        profile = self.repository.get_profile(user_id)
        if profile is None:
            raise DomainNotFoundError("완료된 프로필이 없습니다.")
        return profile

    def save_profile(self, user_id: str, payload: ProfileInput) -> ProfileResponse:
        assert payload.due_date is not None
        today = date.today()
        pregnancy_days = 280 - (payload.due_date - today).days
        pregnancy_weeks = max(0, min(42, pregnancy_days // 7))
        age = today.year - payload.birth_date.year - (
            (today.month, today.day) < (payload.birth_date.month, payload.birth_date.day)
        )
        profile = ProfileResponse(
            **payload.model_dump(),
            pregnancy_weeks=pregnancy_weeks,
            age=age,
            updated_at=datetime.now(timezone.utc),
        )
        return self.repository.save_profile(user_id, profile)

    @staticmethod
    def _destination(
        role: UserRole,
        profile: ProfileCompletion | None,
        partner_link: PartnerLinkStatus,
    ) -> EntryDestination:
        if role == UserRole.WIFE:
            return (
                EntryDestination.WIFE_HOME
                if profile == ProfileCompletion.COMPLETE
                else EntryDestination.WIFE_PROFILE
            )
        return (
            EntryDestination.HUSBAND_CALENDAR
            if partner_link == PartnerLinkStatus.LINKED
            else EntryDestination.HUSBAND_INVITATION_REQUIRED
        )
