from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel

from app.api.v1.domain_errors import to_http_exception
from app.core.security import CurrentUser, get_current_user
from app.core.config import Settings, get_settings
from app.domains.account.session_service import configured_email, issue_account_session
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
SettingsDependency = Annotated[Settings, Depends(get_settings)]


class AccountSwitchInput(BaseModel):
    target: Literal["wife", "husband"]


def _require_local_request(request: Request) -> None:
    """Passwordless account access is available only on the presentation machine."""
    if request.client is None or request.client.host not in {"127.0.0.1", "::1"}:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "로컬 앱에서만 사용할 수 있습니다.")


@router.post("/session/default")
def default_session(request: Request, response: Response, settings: SettingsDependency) -> dict[str, str]:
    """Start each fresh app launch with the configured wife account."""
    _require_local_request(request)
    response.headers["Cache-Control"] = "no-store"
    return issue_account_session(settings, "wife")


@router.post("/session/switch")
def switch_session(
    request: Request,
    response: Response,
    payload: AccountSwitchInput,
    user: User,
    settings: SettingsDependency,
) -> dict[str, str]:
    """Only either configured account may request the other account's session."""
    _require_local_request(request)
    known_emails = {
        configured_email(settings, "wife").strip().lower(),
        configured_email(settings, "husband").strip().lower(),
    }
    if not user.email or user.email.lower() not in known_emails:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "전환 가능한 계정이 아닙니다.")
    response.headers["Cache-Control"] = "no-store"
    return issue_account_session(settings, payload.target)


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
