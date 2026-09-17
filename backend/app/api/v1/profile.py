from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import CurrentUser, get_current_user
from app.schemas.profile import (
    AllergiesInput,
    BodyInput,
    DueDateInput,
    MedicalNotesInput,
    PregnancyCountInput,
    PregnancyHistoryInput,
    ProfileResponse,
)
from app.services.profile_service import (
    ProfileService,
    ProfileStepOrderError,
    ProfileStorageError,
)
from app.services.supabase_service import get_supabase_service

STEP_ORDER_ERROR_DETAIL = "출산예정일(1단계)을 먼저 저장해 주세요."

router = APIRouter(prefix="/profile/me", tags=["profile"])

STORAGE_UNAVAILABLE = "프로필 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_profile_service() -> ProfileService:
    try:
        return ProfileService(get_supabase_service().client)
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[ProfileService, Depends(get_profile_service)]


@router.get("")
def read_my_profile(user: User, service: Service) -> ProfileResponse:
    """저장된 프로필과 완료 단계. 프로필 설정 이어하기·진행바에 쓴다."""
    try:
        profile = service.get(user.id)
    except ProfileStorageError as error:
        raise _storage_unavailable() from error
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "등록된 프로필이 없습니다.")
    return profile


@router.put("/due-date")
def save_due_date(payload: DueDateInput, user: User, service: Service) -> ProfileResponse:
    """프로필 설정 1/6 — 출산예정일(또는 마지막 생리 시작일) 저장."""
    try:
        return service.save_due_date(user.id, payload)
    except ProfileStorageError as error:
        raise _storage_unavailable() from error


@router.put("/body")
def save_body(payload: BodyInput, user: User, service: Service) -> ProfileResponse:
    """프로필 설정 2/6 — 임신 전 신장·체중 저장."""
    try:
        return service.save_body(user.id, payload)
    except ProfileStepOrderError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, STEP_ORDER_ERROR_DETAIL) from error
    except ProfileStorageError as error:
        raise _storage_unavailable() from error


@router.put("/pregnancy-history")
def save_pregnancy_history(
    payload: PregnancyHistoryInput, user: User, service: Service
) -> ProfileResponse:
    """프로필 설정 3/6 — 초산/경산 여부 저장."""
    try:
        return service.save_pregnancy_history(user.id, payload)
    except ProfileStepOrderError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, STEP_ORDER_ERROR_DETAIL) from error
    except ProfileStorageError as error:
        raise _storage_unavailable() from error


@router.put("/pregnancy-count")
def save_pregnancy_count(
    payload: PregnancyCountInput, user: User, service: Service
) -> ProfileResponse:
    """프로필 설정 4/6 — 단태/쌍태 여부 저장."""
    try:
        return service.save_pregnancy_count(user.id, payload)
    except ProfileStepOrderError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, STEP_ORDER_ERROR_DETAIL) from error
    except ProfileStorageError as error:
        raise _storage_unavailable() from error


@router.put("/allergies")
def save_allergies(payload: AllergiesInput, user: User, service: Service) -> ProfileResponse:
    """프로필 설정 5/6 — 알레르기 저장."""
    try:
        return service.save_allergies(user.id, payload)
    except ProfileStepOrderError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, STEP_ORDER_ERROR_DETAIL) from error
    except ProfileStorageError as error:
        raise _storage_unavailable() from error


@router.put("/medical-notes")
def save_medical_notes(
    payload: MedicalNotesInput, user: User, service: Service
) -> ProfileResponse:
    """프로필 설정 6/6 — 주의 진단·자유 텍스트 저장."""
    try:
        return service.save_medical_notes(user.id, payload)
    except ProfileStepOrderError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, STEP_ORDER_ERROR_DETAIL) from error
    except ProfileStorageError as error:
        raise _storage_unavailable() from error
