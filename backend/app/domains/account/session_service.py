"""Issue real Supabase sessions for the two configured presentation accounts."""

from typing import Literal

import httpx
from fastapi import HTTPException, status
from supabase import create_client
from supabase_auth.errors import AuthError

from app.core.config import Settings

AccountRole = Literal["wife", "husband"]


def configured_email(settings: Settings, role: AccountRole) -> str:
    return settings.plm_wife_email if role == "wife" else settings.plm_husband_email


def issue_account_session(settings: Settings, role: AccountRole) -> dict[str, str]:
    """Sign in with an isolated public-key client; never alter the service-role client."""
    email = configured_email(settings, role).strip()
    password = (
        settings.plm_wife_password if role == "wife" else settings.plm_husband_password
    ).get_secret_value()
    public_key = settings.supabase_anon_key.get_secret_value()
    if not settings.supabase_url or not public_key or not email or not password:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "계정 전환 설정이 완료되지 않았습니다.")

    try:
        client = create_client(settings.supabase_url, public_key)
        response = client.auth.sign_in_with_password({"email": email, "password": password})
    except (AuthError, httpx.HTTPError, ValueError) as error:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "계정에 로그인하지 못했습니다.") from error

    if (
        response.session is None
        or response.user is None
        or (response.user.email or "").lower() != email.lower()
    ):
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "계정 세션을 확인하지 못했습니다.")
    return {
        "account": role,
        "user_id": response.user.id,
        "access_token": response.session.access_token,
        "refresh_token": response.session.refresh_token,
    }
