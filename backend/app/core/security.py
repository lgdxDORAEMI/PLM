"""Supabase access token으로 요청 사용자를 확인한다."""

from dataclasses import dataclass
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase_auth.errors import AuthError, AuthRetryableError

from app.services.supabase_service import SupabaseService, get_supabase_service

bearer_scheme = HTTPBearer(auto_error=False)

AUTH_UNAVAILABLE = "인증 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."


@dataclass(frozen=True)
class CurrentUser:
    id: str


def _unauthorized() -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED,
        "로그인이 필요합니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    supabase: Annotated[SupabaseService, Depends(get_supabase_service)],
) -> CurrentUser:
    if credentials is None:
        raise _unauthorized()
    return get_user_from_token(credentials.credentials, supabase)


def get_user_from_token(token: str, supabase: SupabaseService) -> CurrentUser:
    """access token 하나로 사용자를 확인한다. get_current_user()가 이걸 감싼 것이고,
    HTTP Authorization 헤더를 못 쓰는 곳(예: movement WebSocket — 토큰을 쿼리
    파라미터로 받는다, 2026-09-16 결정)에서 직접 재사용한다."""
    try:
        client = supabase.client
    except ValueError as error:  # Supabase 환경변수 누락
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, AUTH_UNAVAILABLE) from error
    try:
        response = client.auth.get_user(token)
    except (AuthRetryableError, httpx.HTTPError) as error:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, AUTH_UNAVAILABLE) from error
    except AuthError as error:
        raise _unauthorized() from error
    if response is None or response.user is None:
        raise _unauthorized()
    return CurrentUser(id=response.user.id)
