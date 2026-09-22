"""Account 도메인 중 파트너 연동(관계 테이블)만 실제 DB에 연결한다(STEP 13).

핵심 원칙: 아내 데이터를 `husband_*` 복제 테이블로 저장하지 않는다.
`partner_links`/`partner_invitations`는 아내·남편이 함께 참조하는 관계
레코드이고, 접근 권한 검증은 항상 이 테이블을 거친다 — 가사 요청 확인
(family/service.py `_partner_request`)과 오전 리포트 조회(STEP 12
`SupabaseFamilyRepository`)가 이미 이렇게 되어 있다. 이 파일은 그 관계를
"만드는" 쪽(초대 발급·수락)을 실제로 연결해 체인을 완성한다.

프로필 저장은 `/api/v1/profile/me/*`(app/services/profile_service.py, 실제
Supabase 연동)가 전담한다 — 한때 여기 있던 get_profile/save_profile(6단계
일괄 Stub)은 birth_date를 포함해 그쪽과 계약이 중복돼 있었고, Frontend가
호출하지 않는 죽은 코드라 제거했다(2026-09-20).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Callable
from uuid import uuid4

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainConflictError, DomainStorageError
from app.services.profile_service import PROFILE_COLUMNS, completed_step

from .repository import AccountRepository, AccountState, InvitationRecord
from .schemas import PartnerLinkStatus, ProfileCompletion, UserRole


class SupabaseAccountRepository(AccountRepository):
    def __init__(self, client: Client) -> None:
        self.client = client

    def get_state(self, user_id: str) -> AccountState:
        role = self._role(user_id)
        profile = self._profile_completion(user_id) if role == UserRole.WIFE else None
        partner_link, partner_display_name = self._partner_link(user_id, role)
        return AccountState(
            role=role,
            profile=profile,
            partner_link=partner_link,
            partner_display_name=partner_display_name,
            my_display_name=self._display_name(user_id),
        )

    def create_invitation(self, user_id: str, *, expires_at: datetime) -> InvitationRecord:
        row = {
            "wife_user_id": user_id,
            "token": uuid4().hex,
            "expires_at": expires_at.isoformat(),
        }
        rows = self._run(lambda: self.client.table("partner_invitations").insert(row).execute())
        saved = rows[0]
        return InvitationRecord(
            invitation_id=saved["id"],
            token=saved["token"],
            wife_user_id=user_id,
            expires_at=expires_at,
            used_at=None,
        )

    def find_invitation_by_token(self, token: str) -> InvitationRecord | None:
        rows = self._run(
            lambda: self.client.table("partner_invitations")
            .select("id,wife_user_id,token,expires_at,used_at")
            .eq("token", token)
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        row = rows[0]
        return InvitationRecord(
            invitation_id=row["id"],
            token=row["token"],
            wife_user_id=row["wife_user_id"],
            expires_at=_parse_dt(row["expires_at"]),
            used_at=_parse_dt(row["used_at"]) if row.get("used_at") else None,
        )

    def mark_invitation_used(self, invitation_id: str, *, used_at: datetime) -> None:
        self._run(
            lambda: self.client.table("partner_invitations")
            .update({"used_at": used_at.isoformat()})
            .eq("id", invitation_id)
            .execute()
        )

    def link_partner(self, wife_user_id: str, husband_user_id: str) -> None:
        """`partner_links`가 유일한 SOURCE다 — 복제하지 않는다. unique(husband_user_id)
        제약을 그대로 신뢰해 "이미 다른 아내와 연동됨"을 DomainConflictError(409)로
        구분해서 알린다(그냥 503으로 보이면 안 됨)."""
        try:
            self.client.table("partner_links").upsert(
                {"wife_user_id": wife_user_id, "husband_user_id": husband_user_id},
                on_conflict="wife_user_id",
                default_to_null=False,
            ).execute()
        except APIError as error:
            if getattr(error, "code", None) == "23505":
                raise DomainConflictError("이미 다른 아내와 연동된 계정입니다.") from error
            raise DomainStorageError("계정/연동 저장소에 연결할 수 없습니다.") from error
        except httpx.HTTPError as error:
            raise DomainStorageError("계정/연동 저장소에 연결할 수 없습니다.") from error

        # 남편 role은 초대 수락 시점에 처음 확정된다(DB_ERD_스키마.md 주석: "초대
        # 링크 수락 가입 → husband"). husband_* 복제 테이블이 아니라 부부가 함께
        # 쓰는 profiles에 role만 기록한다 — 이 role 자체는 OWNED BY HUSBAND다.
        self._run(
            lambda: self.client.table("profiles")
            .upsert(
                {"user_id": husband_user_id, "role": UserRole.HUSBAND.value},
                on_conflict="user_id",
                default_to_null=False,
            )
            .execute()
        )

    def _role(self, user_id: str) -> UserRole:
        rows = self._run(
            lambda: self.client.table("profiles")
            .select("role")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if rows and rows[0].get("role"):
            return UserRole(rows[0]["role"])
        # profiles 행이 아직 없으면 Wife로 본다 — DOMAIN_OWNERSHIP.md가 이미 문서화한
        # 기존 Stub 기본값과 같은 결정이다(role 조회 자체가 안 되는 신규 사용자 = 아직
        # 아무 것도 안 한 아내로 취급). 남편은 초대 수락(link_partner) 시점에 profiles
        # 행이 생기므로 그 전까지는 이 기본값을 거치지 않는다.
        return UserRole.WIFE

    def _profile_completion(self, user_id: str) -> ProfileCompletion:
        rows = self._run(
            lambda: self.client.table("pregnancy_profiles")
            .select(*PROFILE_COLUMNS)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not rows:
            return ProfileCompletion.MISSING
        # profile_service.completed_step()을 그대로 재사용한다 — 완료 판정 로직을
        # 두 곳에 따로 두지 않는다(ponytail: 재사용). 이 함수는 5~6단계
        # (allergies/medical_conditions)를 NULL 판정 불가로 이미 제외하므로
        # 여기서 "완료"는 최대 4단계 기준이다(STEP 10에서 문서화된 제약과 동일).
        return (
            ProfileCompletion.COMPLETE
            if completed_step(rows[0]) >= 4
            else ProfileCompletion.INCOMPLETE
        )

    def _partner_link(
        self, user_id: str, role: UserRole
    ) -> tuple[PartnerLinkStatus, str | None]:
        column = "wife_user_id" if role == UserRole.WIFE else "husband_user_id"
        rows = self._run(
            lambda: self.client.table("partner_links")
            .select("wife_user_id,husband_user_id")
            .eq(column, user_id)
            .limit(1)
            .execute()
        )
        if not rows:
            return PartnerLinkStatus.UNLINKED, None
        partner_id = rows[0]["husband_user_id"] if role == UserRole.WIFE else rows[0]["wife_user_id"]
        return PartnerLinkStatus.LINKED, self._display_name(partner_id)

    def _display_name(self, user_id: str) -> str | None:
        rows = self._run(
            lambda: self.client.table("profiles")
            .select("display_name")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return rows[0].get("display_name") if rows else None

    def _run(self, request: Callable[[], Any]) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("계정/연동 저장소에 연결할 수 없습니다.") from error


def _parse_dt(value: str) -> datetime:
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
