from datetime import date
from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from postgrest.exceptions import APIError

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
    RoutineItemResponse,
    RoutineItemUpdateInput,
    SleepEnvironmentInput,
)
from app.domains.care.service import CareService, CareServicePort
from app.domains.care.stub_repository import StubCareRepository
from app.domains.care.supabase_repository import SupabaseCareRepository
from app.services.supabase_service import get_supabase_service

router = APIRouter(prefix="/care", tags=["care"])
# Record/Report/Household는 아직 이 Stub에 남아 있다 — Condition만 실제 DB로
# 옮겼다(STEP 9). 모듈 싱글턴으로 둬야 재시작 전까지 상태가 유지된다(기존과 동일).
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
    """FUC-W-MEAL-003/004: 챗봇이 제안한 대체 메뉴 수락/거절/재요청 반영 계약(Stub)."""
    return service.update_routine_item(user.id, item_id, payload)


@router.put(
    "/routine-items/{item_id}/sleep-environment", response_model=RoutineItemResponse
)
def update_sleep_environment(
    item_id: str, payload: SleepEnvironmentInput, user: User, service: Service
) -> RoutineItemResponse:
    """FUC-W-SLEEP-001-1: 수면 환경 AI 권장값 override 계약(Stub)."""
    return service.update_sleep_environment(user.id, item_id, payload)


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


def _resolve_calendar_owner(user_id: str, client) -> str:
    """B-CAL-001(Husband, 읽기 전용): 남편이 조회하면 연동된 아내의 캘린더를
    본다 — partner_links가 유일한 관계 SOURCE다(가사요청·오전리포트
    authorization과 같은 기준). 아내이거나 연동이 없으면 본인 id 그대로
    쓴다(기존 동작 유지, 쓰기 API가 없어 권한 분기는 조회 하나로 충분하다)."""
    try:
        rows = (
            client.table("partner_links")
            .select("wife_user_id")
            .eq("husband_user_id", user_id)
            .limit(1)
            .execute()
            .data
        )
    except (APIError, httpx.HTTPError) as error:
        # 이 함수는 FastAPI 의존성으로 쓰여 라우트 본문의 try/except를 거치지
        # 않으므로, DomainStorageError가 아니라 HTTPException을 직접 던진다
        # (get_care_service의 기존 컨벤션과 동일).
        raise _storage_unavailable() from error
    return rows[0]["wife_user_id"] if rows else user_id


def _calendar_supabase_client():
    try:
        return get_supabase_service().client
    except ValueError as error:
        raise _storage_unavailable() from error


def get_calendar_target_user_id(
    user: User, client=Depends(_calendar_supabase_client)
) -> str:
    return _resolve_calendar_owner(user.id, client)


CalendarTarget = Annotated[str, Depends(get_calendar_target_user_id)]


@router.get("/calendar/{month}", response_model=CalendarMonthResponse)
def read_calendar(
    month: str, target_user_id: CalendarTarget, service: Service
) -> CalendarMonthResponse:
    try:
        return service.calendar(target_user_id, month)
    except Exception as error:
        raise to_http_exception(error) from error
