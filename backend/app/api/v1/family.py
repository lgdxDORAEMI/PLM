from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
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
from app.domains.family.supabase_repository import SupabaseFamilyRepository
from app.services.supabase_service import get_supabase_service

router = APIRouter(prefix="/family", tags=["family"])
# household-requests/notifications/motion은 아직 이 Stub에 남아 있다 — 오전
# 리포트(get_morning_report)만 실제 DB로 옮겼다(STEP 12). 모듈 싱글턴으로 둬야
# 재시작 전까지 상태가 유지된다(기존과 동일).
_stub_repository = StubFamilyRepository()
_stub_care_repository = StubCareRepository()

STORAGE_UNAVAILABLE = "가족 공유 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_family_service() -> FamilyServicePort:
    try:
        client = get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error
    return FamilyService(
        SupabaseFamilyRepository(client, fallback=_stub_repository),
        SupabaseCareRepository(client, fallback=_stub_care_repository),
    )


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
    try:
        return service.list_requests(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


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
    "/household-requests/{request_id}/items/{item_id}/confirm",
    response_model=HouseholdRequestResponse,
)
def confirm_household_request_item(
    request_id: str, item_id: str, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.confirm_item(user.id, request_id, item_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/household-requests/{request_id}/items/{item_id}/complete",
    response_model=HouseholdRequestResponse,
)
def complete_household_request_item(
    request_id: str, item_id: str, user: User, service: Service
) -> HouseholdRequestResponse:
    try:
        return service.complete_item(user.id, request_id, item_id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/notifications", response_model=list[NotificationResponse])
def list_notifications(user: User, service: Service) -> list[NotificationResponse]:
    try:
        return service.notifications(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


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
    try:
        return service.motion_privacy(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/motion/consent", response_model=MotionPrivacyResponse)
def grant_motion_consent(user: User, service: Service) -> MotionPrivacyResponse:
    try:
        return service.grant_motion_consent(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


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
    try:
        return service.withdraw_motion_consent(user.id)
    except Exception as error:
        raise to_http_exception(error) from error
