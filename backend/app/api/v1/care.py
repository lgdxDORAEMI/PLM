from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.care.schemas import (
    CalendarMonthResponse,
    ConditionInput,
    ConditionResponse,
    DailyReportResponse,
    PlannedActivitiesInput,
    RoutineExecutionInput,
    RoutineExecutionResponse,
)
from app.domains.care.service import CareService, CareServicePort
from app.domains.care.stub_repository import StubCareRepository

router = APIRouter(prefix="/care", tags=["care"])
_repository = StubCareRepository()


def get_care_service() -> CareServicePort:
    return CareService(_repository)


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[CareServicePort, Depends(get_care_service)]


@router.get("/conditions/{target_date}", response_model=ConditionResponse)
def read_condition(target_date: date, user: User, service: Service) -> ConditionResponse:
    try:
        return service.get_condition(user.id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/conditions/{target_date}", response_model=ConditionResponse)
def save_condition(
    target_date: date, payload: ConditionInput, user: User, service: Service
) -> ConditionResponse:
    return service.save_condition(user.id, target_date, payload)


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
    return service.set_execution(user.id, item_id, payload)


@router.post("/daily-reports/{target_date}/preview", response_model=DailyReportResponse)
def preview_report(target_date: date, user: User, service: Service) -> DailyReportResponse:
    try:
        return service.preview_report(user.id, target_date)
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
def read_report(target_date: date, user: User, service: Service) -> DailyReportResponse:
    try:
        return service.get_report(user.id, target_date)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/calendar/{month}", response_model=CalendarMonthResponse)
def read_calendar(month: str, user: User, service: Service) -> CalendarMonthResponse:
    return service.calendar(user.id, month)
