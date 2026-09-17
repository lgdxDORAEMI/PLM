from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.account.schemas import (
    BootstrapResponse,
    InvitationResponse,
    PartnerLinkResponse,
    ProfileInput,
    ProfileResponse,
)
from app.domains.account.service import AccountService, AccountServicePort
from app.domains.account.stub_repository import StubAccountRepository
from app.domains.account.supabase_repository import SupabaseAccountRepository
from app.services.supabase_service import get_supabase_service

router = APIRouter(prefix="/account", tags=["account"])
# 프로필(GET/PUT /account/profile, 6단계 통합)은 아직 이 Stub에 남아 있다 —
# 파트너 연동(bootstrap/partner-link/invitations)만 실제 DB로 옮겼다(STEP 13).
# 모듈 싱글턴으로 둬야 재시작 전까지 상태가 유지된다(기존과 동일).
_stub_repository = StubAccountRepository()

STORAGE_UNAVAILABLE = "계정/연동 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_account_service() -> AccountServicePort:
    try:
        client = get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error
    return AccountService(SupabaseAccountRepository(client, fallback=_stub_repository))


User = Annotated[CurrentUser, Depends(get_current_user)]
Service = Annotated[AccountServicePort, Depends(get_account_service)]


@router.get("/bootstrap", response_model=BootstrapResponse)
def bootstrap(user: User, service: Service) -> BootstrapResponse:
    """FUC-B-ENTRY-001: 인증 사용자 상태에 맞는 최초 목적지를 반환한다."""
    try:
        return service.bootstrap(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/partner-link", response_model=PartnerLinkResponse)
def read_partner_link(user: User, service: Service) -> PartnerLinkResponse:
    try:
        return service.partner_link(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.get("/profile", response_model=ProfileResponse)
def read_profile(user: User, service: Service) -> ProfileResponse:
    try:
        return service.get_profile(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.put("/profile", response_model=ProfileResponse)
def save_profile(
    payload: ProfileInput, user: User, service: Service
) -> ProfileResponse:
    """6단계 확인 화면에서만 호출하는 원자적 최종 저장 계약."""
    try:
        return service.save_profile(user.id, payload)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/partner-invitations",
    response_model=InvitationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_partner_invitation(user: User, service: Service) -> InvitationResponse:
    """FUC-W-INVITE-001: 72시간 이내 1회성 초대 링크 발급 계약."""
    try:
        return service.issue_invitation(user.id)
    except Exception as error:
        raise to_http_exception(error) from error


@router.post(
    "/partner-invitations/{token}/accept",
    response_model=PartnerLinkResponse,
)
def accept_partner_invitation(
    token: str, user: User, service: Service
) -> PartnerLinkResponse:
    """FUC-H-INVITE-001: 초대 수락 계약(Stub). 화면·인증 복귀 흐름은 미확정(TBD)."""
    try:
        return service.accept_invitation(user.id, token)
    except Exception as error:
        raise to_http_exception(error) from error
