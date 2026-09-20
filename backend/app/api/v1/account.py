from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.domains.account.schemas import (
    BootstrapResponse,
    InvitationResponse,
    PartnerLinkResponse,
)
from app.domains.account.service import AccountService, AccountServicePort
from app.domains.account.supabase_repository import SupabaseAccountRepository
from app.services.supabase_service import get_supabase_service

router = APIRouter(prefix="/account", tags=["account"])

STORAGE_UNAVAILABLE = "계정/연동 저장소에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _storage_unavailable() -> HTTPException:
    return HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE)


def get_account_service() -> AccountServicePort:
    try:
        client = get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise _storage_unavailable() from error
    return AccountService(SupabaseAccountRepository(client))


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
