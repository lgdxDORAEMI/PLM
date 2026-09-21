from datetime import date, datetime, timezone
from uuid import uuid4

from .repository import FamilyRepository, PartnerIdentity
from .schemas import (
    HouseholdDailySummary,
    HouseholdItemStatus,
    HouseholdRequestCreate,
    HouseholdRequestItem,
    HouseholdRequestResponse,
    HouseholdRequestStatus,
    MorningReportResponse,
    MotionPrivacyResponse,
    NotificationResponse,
)


class StubFamilyRepository(FamilyRepository):
    """상태 전이와 권한 계약을 검증하는 메모리 Stub."""

    def __init__(self) -> None:
        self._partners: dict[str, PartnerIdentity] = {}
        self._requests: dict[str, HouseholdRequestResponse] = {}
        self._owners: dict[str, tuple[str, str]] = {}
        self._notifications: dict[str, list[NotificationResponse]] = {}
        self._privacy: dict[str, MotionPrivacyResponse] = {}
        self._morning_reports: dict[tuple[str, date], MorningReportResponse] = {}

    def get_partner(self, wife_user_id: str) -> PartnerIdentity | None:
        return self._partners.get(wife_user_id)

    def create_request(
        self,
        wife_user_id: str,
        wife_display_name: str,
        partner: PartnerIdentity,
        payload: HouseholdRequestCreate,
    ) -> HouseholdRequestResponse:
        request_id = str(uuid4())
        response = HouseholdRequestResponse(
            request_id=request_id,
            target_date=payload.target_date,
            requester_display_name=wife_display_name,
            recipient_display_name=partner.display_name,
            reason=payload.reason,
            status=HouseholdRequestStatus.UNCONFIRMED,
            items=[
                HouseholdRequestItem(
                    item_id=str(uuid4()),
                    status=HouseholdItemStatus.UNCONFIRMED,
                    **item.model_dump(),
                )
                for item in payload.items
            ],
            requested_at=datetime.now(timezone.utc),
            daily_summary=HouseholdDailySummary(requested=0, confirmed=0, completed=0),
        )
        self._requests[request_id] = response
        self._owners[request_id] = (wife_user_id, partner.user_id)
        response = response.model_copy(
            update={"daily_summary": self._daily_summary(wife_user_id, payload.target_date)}
        )
        self._requests[request_id] = response
        return response

    def get_request(self, request_id: str) -> HouseholdRequestResponse | None:
        request = self._requests.get(request_id)
        if request is None:
            return None
        wife_user_id, _ = self._owners[request_id]
        return request.model_copy(
            update={
                "daily_summary": self._daily_summary(wife_user_id, request.target_date)
            }
        )

    def _daily_summary(
        self, wife_user_id: str, target_date: date
    ) -> HouseholdDailySummary:
        """해당 날짜에 아내가 보낸 모든 요청의 항목(item) 개수를 status별로 합산한다
        (SupabaseFamilyRepository._daily_summary와 동일한 집계 규칙)."""
        requested = confirmed = completed = 0
        for request_id, request in self._requests.items():
            if request.target_date != target_date:
                continue
            if self._owners[request_id][0] != wife_user_id:
                continue
            count = len(request.items)
            requested += count
            if request.status in (
                HouseholdRequestStatus.CONFIRMED,
                HouseholdRequestStatus.COMPLETED,
            ):
                confirmed += count
            if request.status == HouseholdRequestStatus.COMPLETED:
                completed += count
        return HouseholdDailySummary(
            requested=requested, confirmed=confirmed, completed=completed
        )

    def request_owner_ids(self, request_id: str) -> tuple[str, str] | None:
        return self._owners.get(request_id)

    def save_request(self, request: HouseholdRequestResponse) -> None:
        self._requests[request.request_id] = request

    def list_requests(self, user_id: str) -> list[HouseholdRequestResponse]:
        return [
            request.model_copy(
                update={
                    "daily_summary": self._daily_summary(
                        self._owners[request_id][0], request.target_date
                    )
                }
            )
            for request_id, request in self._requests.items()
            if user_id in self._owners[request_id]
        ]

    def add_notification(
        self, recipient_user_id: str, notification: NotificationResponse
    ) -> None:
        self._notifications.setdefault(recipient_user_id, []).append(notification)

    def list_notifications(self, recipient_user_id: str) -> list[NotificationResponse]:
        return sorted(
            self._notifications.get(recipient_user_id, []),
            key=lambda item: item.created_at,
            reverse=True,
        )

    def read_notification(
        self, recipient_user_id: str, notification_id: str, read_at: datetime
    ) -> NotificationResponse | None:
        notifications = self._notifications.get(recipient_user_id, [])
        for index, notification in enumerate(notifications):
            if notification.notification_id == notification_id:
                updated = notification.model_copy(update={"read_at": read_at})
                notifications[index] = updated
                return updated
        return None

    def get_motion_privacy(self, user_id: str) -> MotionPrivacyResponse:
        return self._privacy.get(
            user_id,
            MotionPrivacyResponse(
                consent_granted=False,
                collection_enabled=False,
                updated_at=datetime.now(timezone.utc),
            ),
        )

    def save_motion_privacy(
        self, user_id: str, value: MotionPrivacyResponse
    ) -> MotionPrivacyResponse:
        self._privacy[user_id] = value
        return value

    def get_morning_report(
        self, husband_user_id: str, target_date: date
    ) -> MorningReportResponse | None:
        return self._morning_reports.get((husband_user_id, target_date))

    def link_for_demo(
        self,
        wife_user_id: str,
        husband_user_id: str,
        husband_display_name: str = "남편",
    ) -> None:
        """테스트 fixture 전용이며 공개 API로 Partner 연결을 만들지 않는다."""
        self._partners[wife_user_id] = PartnerIdentity(
            user_id=husband_user_id,
            display_name=husband_display_name,
        )
