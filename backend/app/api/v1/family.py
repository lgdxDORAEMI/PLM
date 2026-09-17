from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.family.schemas import (
    HouseholdRequestCreate,
    HouseholdRequestResponse,
    MorningReportResponse,
    MotionCollectionInput,
    MotionPrivacyResponse,
    NotificationResponse,
)
from app.domains.family.service import FamilyService, FamilyServicePort
from app.domains.family.stub_repository import StubFamilyRepository

router = APIRouter(prefix="/family", tags=["family"])
_repository = StubFamilyRepository()


def get_family_service() -> FamilyServicePort:
    return FamilyService(_repository)


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[FamilyServicePort, Depends(get_family_service)]


@router.post(
    "/household-requests",
    response_model=HouseholdRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_household_request(
    payload: HouseholdRequestCreate, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.create_request(user.id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/household-requests", response_model=list[HouseholdRequestResponse])
def list_household_requests(user: User, service: Service) -> list[HouseholdRequestResponse]:
    return service.list_requests(user.id)


@router.get(
    "/household-requests/{request_id}", response_model=HouseholdRequestResponse
)
def read_household_request(
    request_id: str, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.get_request(user.id, request_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/household-requests/{request_id}/confirm",
    response_model=HouseholdRequestResponse,
)
def confirm_household_request(
    request_id: str, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.confirm_request(user.id, request_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/household-requests/{request_id}/complete",
    response_model=HouseholdRequestResponse,
)
def complete_household_request(
    request_id: str, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.complete_request(user.id, request_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/notifications", response_model=list[NotificationResponse])
def list_notifications(user: User, service: Service) -> list[NotificationResponse]:
    return service.notifications(user.id)


@router.post("/notifications/{notification_id}/read", response_model=NotificationResponse)
def read_notification(
    notification_id: str, user: User, service: Service
) -> NotificationResponse:
    try:
        return service.read_notification(user.id, notification_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/morning-reports/{target_date}", response_model=MorningReportResponse)
def read_morning_report(
    target_date: date, user: User, service: Service
) -> MorningReportResponse:
    try:
        return service.morning_report(user.id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/motion/privacy", response_model=MotionPrivacyResponse)
def read_motion_privacy(user: User, service: Service) -> MotionPrivacyResponse:
    return service.motion_privacy(user.id)


@router.put("/motion/consent", response_model=MotionPrivacyResponse)
def grant_motion_consent(user: User, service: Service) -> MotionPrivacyResponse:
    return service.grant_motion_consent(user.id)


@router.put("/motion/collection", response_model=MotionPrivacyResponse)
def set_motion_collection(
    payload: MotionCollectionInput, user: User, service: Service
) -> MotionPrivacyResponse:
    """FUC-B-MOTION-001: 기존 기록을 지우지 않고 신규 감지만 켜거나 끈다."""
    try:
        return service.set_motion_collection(user.id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.delete("/motion/consent", response_model=MotionPrivacyResponse)
def withdraw_motion_consent(user: User, service: Service) -> MotionPrivacyResponse:
    """NFR-012: 동의 철회와 감지 OFF를 분리하고 철회 즉시 수집도 중단한다."""
    return service.withdraw_motion_consent(user.id)
