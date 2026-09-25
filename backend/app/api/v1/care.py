from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.domain_errors import to_http_exception
from app.api.v1.partner_scope import DataOwnerUserId
from app.core.security import CurrentUser, get_current_user
from app.domains.care.schemas import (
    CalendarDayDetailResponse,
    CalendarMonthResponse,
    ConditionInput,
    ConditionResponse,
    DailyReportResponse,
    PlannedActivitiesInput,
    RoutineExecutionInput,
    RoutineExecutionResponse,
    RoutineItemResponse,
    RoutineItemUpdateInput,
    SleepEnvironmentInput,
)
from app.domains.care.service import CareService, CareServicePort
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
from app.services.supabase_service import get_supabase_service
from app.utils import dates

router = APIRouter(prefix="/care", tags=["care"])
# Care 도메인은 전부 Supabase 실연결이다. Stub은 SupabaseCareRepository의 fallback
# 인터페이스용으로만 남아 있다(모듈 싱글턴, 기존과 동일).
_stub_repository = StubCareRepository()

STORAGE_UNAVAILABLE = "컨디션 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_care_service() -> CareServicePort:
    try:
        client = get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error
    return CareService(SupabaseCareRepository(client, fallback=_stub_repository))


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[CareServicePort, Depends(get_care_service)]


@router.post("/today/reset")
def reset_today(user: User, service: Service) -> dict[str, str | bool]:
    """Reset only the authenticated wife's current KST day."""
    today = dates.today_kst()
    try:
        service.reset_today(user.id, today)
    except Exception as error:
        raise to_http_exception(error) from error
    return {"target_date": today.isoformat(), "reset": True}


@router.get("/conditions/{target_date}", response_model=ConditionResponse)
def read_condition(
    target_date: date, target_user_id: DataOwnerUserId, service: Service
) -> ConditionResponse:
    """B-CAL-001과 동일 규칙: 남편은 연동된 아내의 컨디션을 읽기 전용 조회한다."""
    try:
        return service.get_condition(target_user_id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/conditions/{target_date}", response_model=ConditionResponse)
def save_condition(
    target_date: date, payload: ConditionInput, user: User, service: Service
) -> ConditionResponse:
    try:
        return service.save_condition(user.id, target_date, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/conditions/{target_date}/activities", response_model=ConditionResponse)
def save_activities(
    target_date: date,
    payload: PlannedActivitiesInput,
    user: User,
    service: Service,
) -> ConditionResponse:
    try:
        return service.save_activities(user.id, target_date, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/routine-items/{item_id}/execution", response_model=RoutineExecutionResponse)
def set_execution(
    item_id: str, payload: RoutineExecutionInput, user: User, service: Service
) -> RoutineExecutionResponse:
    """FUC-W-RECORD-001: Routine 알고리즘을 수정하지 않는 실행 기록 경계."""
    try:
        return service.set_execution(user.id, item_id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/routine-items/{item_id}", response_model=RoutineItemResponse)
def update_routine_item(
    item_id: str, payload: RoutineItemUpdateInput, user: User, service: Service
) -> RoutineItemResponse:
    """FUC-W-MEAL-003/004: 메뉴 수락/거절/재요청을 recommendation_feedback에 기록한다."""
    try:
        return service.update_routine_item(user.id, item_id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put(
    "/routine-items/{item_id}/sleep-environment", response_model=RoutineItemResponse
)
def update_sleep_environment(
    item_id: str, payload: SleepEnvironmentInput, user: User, service: Service
) -> RoutineItemResponse:
    """FUC-W-SLEEP-001-1: 수면 환경 override를 recommendation_feedback에 기록한다."""
    try:
        return service.update_sleep_environment(user.id, item_id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post("/daily-reports/{target_date}/preview", response_model=DailyReportResponse)
def preview_report(
    target_date: date, target_user_id: DataOwnerUserId, service: Service
) -> DailyReportResponse:
    """B-CAL-001과 동일 규칙: 저장은 안 하는 미리보기라 남편도 읽기 전용 조회 가능."""
    try:
        return service.preview_report(target_user_id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post("/daily-reports/{target_date}/finalize", response_model=DailyReportResponse)
def finalize_report(target_date: date, user: User, service: Service) -> DailyReportResponse:
    """리포트 저장과 루틴 확정은 이 명시적 요청에서만 수행한다."""
    try:
        return service.finalize_report(user.id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/daily-reports/{target_date}", response_model=DailyReportResponse)
def read_report(
    target_date: date, target_user_id: DataOwnerUserId, service: Service
) -> DailyReportResponse:
    """B-CAL-001과 동일 규칙: 남편은 연동된 아내의 확정 리포트를 읽기 전용 조회한다."""
    try:
        return service.get_report(target_user_id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/calendar/{month}", response_model=CalendarMonthResponse)
def read_calendar(
    month: str, target_user_id: DataOwnerUserId, service: Service
) -> CalendarMonthResponse:
    """B-CAL-001: 남편은 partner_links로 연동된 아내 캘린더를 읽기 전용 조회(partner_scope)."""
    try:
        return service.calendar(target_user_id, month)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get(
    "/calendar/days/{target_date}", response_model=CalendarDayDetailResponse
)
def read_calendar_day(
    target_date: date, target_user_id: DataOwnerUserId, service: Service
) -> CalendarDayDetailResponse:
    """선택 날짜의 컨디션과 리포트 미리보기를 한 번에 읽는다."""
    try:
        return service.calendar_day(target_user_id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error
