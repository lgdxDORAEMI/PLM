from dataclasses import dataclass
from datetime import date, datetime
from typing import Protocol

from .schemas import (
    HouseholdRequestCreate,
    HouseholdRequestResponse,
    MotionPrivacyResponse,
    MorningReportResponse,
    NotificationResponse,
)


@dataclass(frozen=True)
class PartnerIdentity:
    user_id: str
    display_name: str


class FamilyRepository(Protocol):
    """가족 공유 데이터 adapter. 원본 Profile과 Chat 저장소에는 접근하지 않는다."""

    def get_partner(self, wife_user_id: str) -> PartnerIdentity | None: ...

    def create_request(
        self,
        wife_user_id: str,
        wife_display_name: str,
        partner: PartnerIdentity,
        payload: HouseholdRequestCreate,
    ) -> HouseholdRequestResponse: ...

    def get_request(self, request_id: str) -> HouseholdRequestResponse | None: ...

    def request_owner_ids(self, request_id: str) -> tuple[str, str] | None: ...

    def save_request(self, request: HouseholdRequestResponse) -> None: ...

    def list_requests(
        self, user_id: str, target_date: date | None = None
    ) -> list[HouseholdRequestResponse]: ...

    def add_notification(
        self, recipient_user_id: str, notification: NotificationResponse
    ) -> None: ...

    def list_notifications(self, recipient_user_id: str) -> list[NotificationResponse]: ...

    def read_notification(
        self, recipient_user_id: str, notification_id: str, read_at: datetime
    ) -> NotificationResponse | None: ...

    def get_motion_privacy(self, user_id: str) -> MotionPrivacyResponse: ...

    def save_motion_privacy(
        self, user_id: str, value: MotionPrivacyResponse
    ) -> MotionPrivacyResponse: ...

    def get_morning_report(
        self, husband_user_id: str, target_date: date
    ) -> MorningReportResponse | None: ...
