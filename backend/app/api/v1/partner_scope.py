"""남편이 조회하면 연동된 아내의 데이터를 본다 — 공유 화면(B-CAL-001, B-MOTION-001)
공통 규칙. `partner_links`가 유일한 관계 SOURCE다(가사요청·오전리포트 authorization과
같은 기준). 아내이거나 연동이 없으면 본인 id 그대로 쓴다(미연동 남편은 본인의 빈
데이터를 보게 되므로 아내 데이터가 새지 않는다)."""

from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, status
from postgrest.exceptions import APIError

from app.core.security import CurrentUser, get_current_user
from app.domains.errors import PARTNER_NOT_SHARED
from app.services.supabase_service import get_supabase_service

STORAGE_UNAVAILABLE = "가족 연동 정보를 확인할 수 없습니다. 잠시 후 다시 시도해 주세요."


def _husband_link(user_id: str, client) -> dict | None:
    try:
        rows = (
            client.table("partner_links")
            .select("wife_user_id,shared_at")
            .eq("husband_user_id", user_id)
            .limit(1)
            .execute()
            .data
        )
    except (APIError, httpx.HTTPError) as error:
        # FastAPI 의존성으로 쓰여 라우트 본문의 try/except를 거치지 않으므로
        # DomainStorageError가 아니라 HTTPException을 직접 던진다.
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE) from error
    return rows[0] if rows else None


def resolve_data_owner(user_id: str, client) -> str:
    """09-29: 아내가 아직 공개하지 않았으면 403이다(리포트·홈캠 조회 차단)."""
    link = _husband_link(user_id, client)
    if link is None:
        return user_id
    if not link.get("shared_at"):
        raise HTTPException(status.HTTP_403_FORBIDDEN, PARTNER_NOT_SHARED)
    return link["wife_user_id"]


def resolve_shared_data_owner(user_id: str, client) -> str | None:
    """캘린더용. 연동은 됐지만 아내가 아직 공개하지 않았으면(shared_at 없음) None이다.
    09-29: 아내가 초기화하면 shared_at이 비고, 초대 화면에서 다시 확인해야 채워진다."""
    link = _husband_link(user_id, client)
    if link is None:
        return user_id
    return link["wife_user_id"] if link.get("shared_at") else None


def get_partner_scope_client():
    try:
        return get_supabase_service().client
    except ValueError as error:  # Supabase 환경변수 누락
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, STORAGE_UNAVAILABLE) from error


def get_data_owner_user_id(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    client=Depends(get_partner_scope_client),
) -> str:
    return resolve_data_owner(user.id, client)


DataOwnerUserId = Annotated[str, Depends(get_data_owner_user_id)]


def get_shared_data_owner_user_id(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    client=Depends(get_partner_scope_client),
) -> str | None:
    return resolve_shared_data_owner(user.id, client)


SharedDataOwnerUserId = Annotated[str | None, Depends(get_shared_data_owner_user_id)]
