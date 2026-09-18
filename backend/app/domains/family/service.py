from datetime import date, datetime, timezone
from typing import Protocol
from uuid import uuid4

from app.domains.errors import (
    DomainConflictError,
    DomainForbiddenError,
    DomainNotFoundError,
)

from .repository import FamilyRepository
from .schemas import (
    HouseholdItemStatus,
    HouseholdRequestCreate,
    HouseholdRequestResponse,
    HouseholdRequestStatus,
    MorningReportResponse,
    MotionCollectionInput,
    MotionPrivacyResponse,
    NotificationResponse,
    NotificationType,
)


class FamilyServicePort(Protocol):
    def create_request(
        self, user_id: str, payload: HouseholdRequestCreate
    ) -> HouseholdRequestResponse: ...

    def list_requests(self, user_id: str) -> list[HouseholdRequestResponse]: ...

    def get_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse: ...

    def confirm_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse: ...

    def complete_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse: ...

    def notifications(self, user_id: str) -> list[NotificationResponse]: ...

    def read_notification(
        self, user_id: str, notification_id: str
    ) -> NotificationResponse: ...

    def notify_routine_ready(
        self, wife_user_id: str, target_date: date, routine_id: str, *, first_of_day: bool
    ) -> None: ...

    def morning_report(self, user_id: str, target_date: date) -> MorningReportResponse: ...

    def motion_privacy(self, user_id: str) -> MotionPrivacyResponse: ...

    def set_motion_collection(
        self, user_id: str, payload: MotionCollectionInput
    ) -> MotionPrivacyResponse: ...

    def grant_motion_consent(self, user_id: str) -> MotionPrivacyResponse: ...

    def withdraw_motion_consent(self, user_id: str) -> MotionPrivacyResponse: ...


class FamilyService(FamilyServicePort):
    def __init__(self, repository: FamilyRepository) -> None:
        self.repository = repository

    def create_request(
        self, user_id: str, payload: HouseholdRequestCreate
    ) -> HouseholdRequestResponse:
        partner = self.repository.get_partner(user_id)
        if partner is None:
            raise DomainConflictError("연동된 남편 계정이 없어 요청을 보낼 수 없습니다.")
        request = self.repository.create_request(user_id, "아내", partner, payload)
        self.repository.add_notification(
            partner.user_id,
            NotificationResponse(
                notification_id=str(uuid4()),
                type=NotificationType.HOUSEHOLD_REQUEST,
                title="가사 요청이 도착했어요",
                body=f"{len(request.items)}개 항목을 확인해 주세요.",
                target_date=request.target_date,
                reference_id=request.request_id,
                created_at=datetime.now(timezone.utc),
            ),
        )
        return request

    def list_requests(self, user_id: str) -> list[HouseholdRequestResponse]:
        return self.repository.list_requests(user_id)

    def get_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse:
        request = self._authorized_request(user_id, request_id)
        return request

    def confirm_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse:
        request = self._partner_request(user_id, request_id)
        if request.status == HouseholdRequestStatus.COMPLETED:
            raise DomainConflictError("이미 완료된 요청입니다.")
        now = datetime.now(timezone.utc)
        updated = request.model_copy(
            update={
                "status": HouseholdRequestStatus.CONFIRMED,
                "confirmed_at": request.confirmed_at or now,
                "items": [
                    item.model_copy(update={"status": HouseholdItemStatus.CONFIRMED})
                    if item.status == HouseholdItemStatus.UNCONFIRMED
                    else item
                    for item in request.items
                ],
            }
        )
        self.repository.save_request(updated)
        return updated

    def complete_request(self, user_id: str, request_id: str) -> HouseholdRequestResponse:
        request = self._partner_request(user_id, request_id)
        if request.status != HouseholdRequestStatus.CONFIRMED:
            raise DomainConflictError("확인 상태의 요청만 완료할 수 있습니다.")
        updated = request.model_copy(
            update={
                "status": HouseholdRequestStatus.COMPLETED,
                "completed_at": datetime.now(timezone.utc),
                "items": [
                    item.model_copy(update={"status": HouseholdItemStatus.COMPLETED})
                    for item in request.items
                ],
            }
        )
        self.repository.save_request(updated)
        # 요구사항에 따라 상태 변경 알림은 새로 만들지 않는다.
        return updated

    def notifications(self, user_id: str) -> list[NotificationResponse]:
        return self.repository.list_notifications(user_id)

    def read_notification(
        self, user_id: str, notification_id: str
    ) -> NotificationResponse:
        notification = self.repository.read_notification(
            user_id, notification_id, datetime.now(timezone.utc)
        )
        if notification is None:
            raise DomainNotFoundError("알림을 찾을 수 없습니다.")
        return notification

    def notify_routine_ready(
        self, wife_user_id: str, target_date: date, routine_id: str, *, first_of_day: bool
    ) -> None:
        """FUC-W-COND-002(첫 생성→오전 리포트)/FUC-W-COND-003(재생성→루틴 변경).
        남편 미연동이면 스펙대로 조용히 생략한다."""
        partner = self.repository.get_partner(wife_user_id)
        if partner is None:
            return
        if first_of_day:
            kind = NotificationType.MORNING_REPORT
            title, body = "오전 컨디션 리포트가 도착했어요", "오늘의 컨디션과 루틴 요약을 확인해 주세요."
        else:
            kind = NotificationType.CONDITION_CHANGED
            title, body = "아내의 루틴이 변경되었습니다.", "변경된 루틴 요약을 캘린더에서 확인해 주세요."
        self.repository.add_notification(
            partner.user_id,
            NotificationResponse(
                notification_id=str(uuid4()),
                type=kind,
                title=title,
                body=body,
                target_date=target_date,
                reference_id=routine_id,
                created_at=datetime.now(timezone.utc),
            ),
        )

    def morning_report(self, user_id: str, target_date: date) -> MorningReportResponse:
        report = self.repository.get_morning_report(user_id, target_date)
        if report is None:
            raise DomainNotFoundError("해당 날짜의 오전 리포트가 없습니다.")
        return report

    def motion_privacy(self, user_id: str) -> MotionPrivacyResponse:
        return self.repository.get_motion_privacy(user_id)

    def set_motion_collection(
        self, user_id: str, payload: MotionCollectionInput
    ) -> MotionPrivacyResponse:
        current = self.repository.get_motion_privacy(user_id)
        if payload.enabled and not current.consent_granted:
            raise DomainConflictError("모션 수집 동의 후 감지를 켤 수 있습니다.")
        return self.repository.save_motion_privacy(
            user_id,
            current.model_copy(
                update={
                    "collection_enabled": payload.enabled,
                    "updated_at": datetime.now(timezone.utc),
                }
            ),
        )

    def grant_motion_consent(self, user_id: str) -> MotionPrivacyResponse:
        current = self.repository.get_motion_privacy(user_id)
        return self.repository.save_motion_privacy(
            user_id,
            current.model_copy(
                update={
                    "consent_granted": True,
                    "updated_at": datetime.now(timezone.utc),
                }
            ),
        )

    def withdraw_motion_consent(self, user_id: str) -> MotionPrivacyResponse:
        current = self.repository.get_motion_privacy(user_id)
        return self.repository.save_motion_privacy(
            user_id,
            current.model_copy(
                update={
                    "consent_granted": False,
                    "collection_enabled": False,
                    "updated_at": datetime.now(timezone.utc),
                }
            ),
        )

    def _authorized_request(
        self, user_id: str, request_id: str
    ) -> HouseholdRequestResponse:
        request = self.repository.get_request(request_id)
        owners = self.repository.request_owner_ids(request_id)
        if request is None or owners is None:
            raise DomainNotFoundError("가사 요청을 찾을 수 없습니다.")
        if user_id not in owners:
            raise DomainForbiddenError("해당 가사 요청을 조회할 권한이 없습니다.")
        return request

    def _partner_request(
        self, user_id: str, request_id: str
    ) -> HouseholdRequestResponse:
        request = self._authorized_request(user_id, request_id)
        owners = self.repository.request_owner_ids(request_id)
        assert owners is not None
        if user_id != owners[1]:
            raise DomainForbiddenError("요청을 받은 남편 계정만 상태를 변경할 수 있습니다.")
        return request
