from datetime import datetime
from uuid import uuid4

from .repository import AccountRepository, AccountState, InvitationRecord
from .schemas import PartnerLinkStatus, ProfileCompletion, ProfileResponse, UserRole


class StubAccountRepository(AccountRepository):
    """DB 연결 전에도 OpenAPI와 Frontend 연동을 확인할 수 있는 프로세스 메모리 Stub."""

    def __init__(self) -> None:
        self._states: dict[str, AccountState] = {}
        self._invitations: dict[str, InvitationRecord] = {}
        self._profiles: dict[str, ProfileResponse] = {}

    def get_state(self, user_id: str) -> AccountState:
        return self._states.get(
            user_id,
            AccountState(
                role=UserRole.WIFE,
                profile=ProfileCompletion.MISSING,
                partner_link=PartnerLinkStatus.UNLINKED,
            ),
        )

    def create_invitation(
        self, user_id: str, *, expires_at: datetime
    ) -> InvitationRecord:
        invitation_id = str(uuid4())
        record = InvitationRecord(
            invitation_id=invitation_id,
            token=uuid4().hex,
            wife_user_id=user_id,
            expires_at=expires_at,
        )
        self._invitations[invitation_id] = record
        return record

    def set_state(self, user_id: str, state: AccountState) -> None:
        """테스트와 로컬 Demo fixture에서만 사용자 상태를 주입한다."""
        self._states[user_id] = state

    def get_profile(self, user_id: str) -> ProfileResponse | None:
        return self._profiles.get(user_id)

    def save_profile(self, user_id: str, profile: ProfileResponse) -> ProfileResponse:
        self._profiles[user_id] = profile
        previous = self.get_state(user_id)
        self._states[user_id] = AccountState(
            role=UserRole.WIFE,
            profile=ProfileCompletion.COMPLETE,
            partner_link=previous.partner_link,
            partner_display_name=previous.partner_display_name,
        )
        return profile
