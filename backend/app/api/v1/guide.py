"""Meal/Household/Health/Sleep 가이드 조회 (W-MEAL-001/002, W-HOUSE-001,
W-HEALTH-001, W-SLEEP-001). Developer A(Daily Experience) 소유.

Routine AI가 만든 routine_items를 읽기만 하는 Query Layer다 — 카테고리별
로 AI를 새로 호출하지 않는다. `app/services/routine/**`, `app/api/v1/routine.py`는
이 파일에서 수정하지 않는다."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.guide.query_service import GuideQueryService
from app.domains.guide.schemas import GuideResponse, RoutineCategory
from app.services.supabase_service import get_supabase_service
from app.utils import dates

router = APIRouter(tags=["guide"])

STORAGE_UNAVAILABLE = "루틴 가이드 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_guide_service() -> GuideQueryService:
    try:
        return GuideQueryService(get_supabase_service().client)
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[GuideQueryService, Depends(get_guide_service)]
TargetDate = Annotated[date | None, Query(alias="date")]


def _read(
    category: RoutineCategory, user: CurrentUser, service: GuideQueryService, target_date: date | None
) -> GuideResponse:
    try:
        return service.get_guide(user.id, target_date or dates.today_kst(), category)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/meals/today", response_model=GuideResponse)
def read_meal_guide(user: User, service: Service, target_date: TargetDate = None) -> GuideResponse:
    """FUC-W-MEAL-001/002: 끼니별 요약·상세 조회."""
    return _read(RoutineCategory.MEAL, user, service, target_date)


@router.get("/household/today", response_model=GuideResponse)
def read_household_guide(
    user: User, service: Service, target_date: TargetDate = None
) -> GuideResponse:
    """FUC-W-HOUSE-001: 가사 3분류 조회."""
    return _read(RoutineCategory.HOUSEHOLD, user, service, target_date)


@router.get("/health/today", response_model=GuideResponse)
def read_health_guide(user: User, service: Service, target_date: TargetDate = None) -> GuideResponse:
    """FUC-W-HEALTH-001: 부위별 활동 추천 조회."""
    return _read(RoutineCategory.HEALTH, user, service, target_date)


@router.get("/sleep/today", response_model=GuideResponse)
def read_sleep_guide(user: User, service: Service, target_date: TargetDate = None) -> GuideResponse:
    """FUC-W-SLEEP-001: 수면 가이드 조회."""
    return _read(RoutineCategory.SLEEP, user, service, target_date)
