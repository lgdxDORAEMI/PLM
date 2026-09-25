from datetime import date, datetime, timezone
from typing import Protocol
from uuid import uuid4

from app.domains.care.repository import CareRepository
from app.domains.care.schemas import (
    CompletionActor,
    ExecutionStatus,
    RoutineExecutionInput,
)
from app.domains.care.stub_repository import StubCareRepository
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

    def confirm_item(
        self, user_id: str, request_id: str, item_id: str
    ) -> HouseholdRequestResponse: ...

    def complete_item(
        self, user_id: str, request_id: str, item_id: str
    ) -> HouseholdRequestResponse: ...

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
    def __init__(
        self, repository: FamilyRepository, care_repository: CareRepository | None = None
    ) -> None:
        self.repository = repository
        # 기존 호출부(테스트 등)는 대부분 가사 요청만 다뤄 이 인자를 안 넘긴다 —
        # 그런 경우엔 routine_items 동기화가 그냥 메모리 Stub에만 반영되고 끝난다.
        self.care_repository = care_repository or StubCareRepository()

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

    def confirm_item(
        self, user_id: str, request_id: str, item_id: str
    ) -> HouseholdRequestResponse:
        request = self._partner_request(user_id, request_id)
        item = self._find_item(request, item_id)
        if item.status != HouseholdItemStatus.UNCONFIRMED:
            raise DomainConflictError("이미 확인된 항목입니다.")
        return self._apply_item_status(request, item_id, HouseholdItemStatus.CONFIRMED)

    def complete_item(
        self, user_id: str, request_id: str, item_id: str
    ) -> HouseholdRequestResponse:
        request = self._partner_request(user_id, request_id)
        item = self._find_item(request, item_id)
        if item.status != HouseholdItemStatus.CONFIRMED:
            raise DomainConflictError("확인 상태의 항목만 완료할 수 있습니다.")
        # 요구사항에 따라 상태 변경 알림은 새로 만들지 않는다.
        updated = self._apply_item_status(request, item_id, HouseholdItemStatus.COMPLETED)
        if item.routine_item_id:
            self._sync_routine_item_completed(request_id, item.routine_item_id)
        return updated

    def _sync_routine_item_completed(self, request_id: str, routine_item_id: str) -> None:
        """홈 화면 '루틴 진행도'가 읽는 routine_items.status를 같이 완료 처리한다 —
        안 하면 가사 요청을 남편이 다 완료해도 진행도가 계속 0으로 남는다.
        요청 소유자는 아내라 routine_items 행도 아내 user_id로 조회된다."""
        owners = self.repository.request_owner_ids(request_id)
        if owners is None:
            return
        wife_user_id, _ = owners
        try:
            self.care_repository.set_execution(
                wife_user_id,
                routine_item_id,
                RoutineExecutionInput(status=ExecutionStatus.COMPLETED),
                actor=CompletionActor.HUSBAND,
            )
        except DomainNotFoundError:
            pass  # 루틴 항목이 이미 없어졌어도(다른 날짜로 넘어감 등) 가사 요청 완료는 유지한다.

    def _find_item(self, request: HouseholdRequestResponse, item_id: str):
        for item in request.items:
            if item.item_id == item_id:
                return item
        raise DomainNotFoundError("집안일 항목을 찾을 수 없습니다.")

    def _apply_item_status(
        self,
        request: HouseholdRequestResponse,
        item_id: str,
        new_status: HouseholdItemStatus,
    ) -> HouseholdRequestResponse:
        """카드(항목)별로 독립된 확인·완료 상태를 관리한다(FUC-H-REQUEST-002) —
        요청 전체 status는 항목들의 상태로부터 다시 계산한다: 전부 completed면
        completed, 하나라도 unconfirmed가 아니면 confirmed."""
        items = [
            item.model_copy(update={"status": new_status})
            if item.item_id == item_id
            else item
            for item in request.items
        ]
        now = datetime.now(timezone.utc)
        if all(item.status == HouseholdItemStatus.COMPLETED for item in items):
            status = HouseholdRequestStatus.COMPLETED
            confirmed_at = request.confirmed_at or now
            completed_at = request.completed_at or now
        elif any(item.status != HouseholdItemStatus.UNCONFIRMED for item in items):
            status = HouseholdRequestStatus.CONFIRMED
            confirmed_at = request.confirmed_at or now
            completed_at = request.completed_at
        else:
            status = HouseholdRequestStatus.UNCONFIRMED
            confirmed_at = request.confirmed_at
            completed_at = request.completed_at
        updated = request.model_copy(
            update={
                "items": items,
                "status": status,
                "confirmed_at": confirmed_at,
                "completed_at": completed_at,
            }
        )
        self.repository.save_request(updated)
        # daily_summary는 그날 다른 요청까지 합산한 값이라 save 시점에 다시
        # 읽어야 한다 — 위 model_copy가 들고 있는 값은 이 항목을 바꾸기 전에
        # 조회했던 stale 값이다.
        refreshed = self.repository.get_request(request.request_id)
        assert refreshed is not None
        return refreshed

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
