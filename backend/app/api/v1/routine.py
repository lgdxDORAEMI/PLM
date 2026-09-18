"""AI 하루 루틴 (W-ROUTINE-001 생성, W-ROUTINE-003 폴백, W-HOME-001 조회)."""

from __future__ import annotations

import logging
from typing import Annotated, Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from postgrest.exceptions import APIError

from app.api.v1.family import get_family_service
from app.core.config import get_settings
from app.core.security import CurrentUser, get_current_user
from app.domains.family.service import FamilyServicePort
from app.services.routine import repository
from app.services.routine.inputs import ConditionMissingError, ProfileMissingError
from app.services.routine.service import RoutineService
from app.services.supabase_service import get_supabase_service
from app.utils import dates

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/routine", tags=["routine"])

STORAGE_UNAVAILABLE = "루틴 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_routine_service() -> RoutineService:
    try:
        return RoutineService(get_supabase_service().client, get_settings())
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[RoutineService, Depends(get_routine_service)]
Family = Annotated[FamilyServicePort, Depends(get_family_service)]


def _with_regeneration_flag(routine: dict[str, Any]) -> dict[str, Any]:
    """S4(R2): revision 2 이상 = 같은 날 재생성. 호출 측(남편 알림·변경 배너)이 이 값으로 분기한다."""
    return {**routine, "is_regeneration": int(routine.get("revision") or 1) > 1}


@router.get("/today")
def read_today(user: User, service: Service) -> dict[str, Any]:
    """오늘 저장된 4종 가이드. 홈 화면 재진입·새로고침용. 없으면 404 → 앱은 컨디션 CTA를 보여준다."""
    try:
        routine = repository.get_routine(service.supabase, user.id, dates.today_kst())
    except (APIError, httpx.HTTPError) as error:
        logger.exception("루틴 조회 실패")
        raise _storage_unavailable() from error
    if routine is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "오늘 생성된 루틴이 없습니다.")
    return _with_regeneration_flag(routine)


@router.post("/today", status_code=status.HTTP_201_CREATED)
async def generate_today(user: User, service: Service, family: Family) -> dict[str, Any]:
    """컨디션·예정 활동 저장 후 호출. AI 실패 시에도 폴백 루틴을 저장해 항상 4종을 돌려준다."""
    today = dates.today_kst()
    try:
        saved = _with_regeneration_flag(await service.generate_today(user.id, today))
    except ProfileMissingError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, "출산예정일(프로필 1단계)을 먼저 저장해 주세요.") from error
    except ConditionMissingError as error:
        raise HTTPException(status.HTTP_409_CONFLICT, "오늘 컨디션을 먼저 입력해 주세요.") from error
    except (APIError, httpx.HTTPError) as error:
        logger.exception("루틴 저장 실패")
        raise _storage_unavailable() from error

    # S5(R3): 폴백(source != ai)은 AI 실패라 앱이 W-CALLBACK-001·재시도를 띄운다 → 남편 알림을 보내지 않는다.
    # 첫 알림 종류는 "오늘 AI 루틴이 처음 나왔는가"로 정한다. 폴백 뒤 재시도 성공도 오전 리포트(FUC-W-COND-002),
    # AI 루틴이 이미 있었으면 루틴 변경(FUC-W-COND-003). 알림 실패는 루틴 생성 성공에 영향을 주지 않는다.
    if saved["source"] == "ai":
        try:
            first = not repository.has_ai_routine_before(service.supabase, user.id, today, int(saved["revision"]))
            family.notify_routine_ready(user.id, today, str(saved["id"]), first_of_day=first)
        except Exception:
            logger.exception("루틴 생성 알림 발송 실패")
    return saved
