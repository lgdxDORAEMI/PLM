"""Family 도메인 중 오전 리포트(STEP 12)와 모션 동의(STEP 14)를 실제 DB에
연결한다.

남편 Report는 아내 데이터의 복사본을 만들지 않는다 — `partner_links`로 연동을
확인(family authorization)한 뒤 아내 소유 테이블(pregnancy_profiles,
daily_conditions, routine_items)을 그 자리에서 읽어 허용된 요약만 내려주는
projection이다. 원본 점수·항목 상세는 절대 응답에 넣지 않는다(NFR-013,
DOMAIN_OWNERSHIP.md: "프로필 원본, 컨디션 원본, AI 대화 원문을 Family 응답
Schema에 넣지 않는다").

STEP 14(Movement Data Integration) 메모: `motion_consents`는 `posture_events`/
`posture_calibration_profiles`와 달리 Protected `app/services/movement/**`가
직접 다루지 않는 테이블이다(동의 여부는 Family 화면 소관, 실제 WS 게이트
연동은 Protected `movement.py` 변경이 필요해 별도 TBD로 남는다 —
DOMAIN_OWNERSHIP.md 기존 TBD). 그래서 이 파일에서 실제 DB로 연결해도 Protected
경계를 넘지 않는다. `posture_events`/`posture_calibration_profiles` 쪽은 이미
`app/services/movement/events.py`의 `EventStore` Protocol(+`InMemoryEventStore`
+`SupabaseEventStore`)이 정확히 "필요하면 MovementEventRepository 경계를
추가한다"에 해당하는 구조를 갖추고 있어 새로 만들 필요가 없었다 — 이 파일은
그 경계를 그대로 재사용만 한다(STEP 12의 `_movement_summary`처럼).

household-requests/notifications은 지원 테이블 연동이 아직 이 STEP 범위가
아니라 fallback(Stub)에 위임한다.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Callable

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainForbiddenError, DomainStorageError
from app.utils import dates

from .repository import FamilyRepository
from .schemas import MorningReportResponse, MotionPrivacyResponse

CONDITION_COLUMNS = (
    "nausea",
    "waist_pain",
    "pelvis_pain",
    "leg_pain",
    "wrist_pain",
    "fatigue",
    "mood",
)

# 원본 점수(1~5)를 그대로 남편에게 보여주지 않는다 — 정성 문구로만 요약한다.
_LOW, _MID = 2, 3
_BURDEN_LABELS_KO = {
    "nausea": "입덧",
    "waist_pain": "허리 통증",
    "pelvis_pain": "골반 통증",
    "leg_pain": "다리 통증",
    "wrist_pain": "손목 통증",
    "fatigue": "피로감",
}


class SupabaseFamilyRepository(FamilyRepository):
    def __init__(self, client: Client, fallback: FamilyRepository) -> None:
        self.client = client
        self.fallback = fallback

    def get_morning_report(
        self, husband_user_id: str, target_date: date
    ) -> MorningReportResponse | None:
        wife_user_id = self._linked_wife_id(husband_user_id)

        profile_rows = self._run(
            lambda: self.client.table("pregnancy_profiles")
            .select("due_date")
            .eq("user_id", wife_user_id)
            .limit(1)
            .execute()
        )
        if not profile_rows or profile_rows[0].get("due_date") is None:
            return None
        due_date = date.fromisoformat(str(profile_rows[0]["due_date"]))
        week, _ = dates.pregnancy_age(due_date, target_date)

        condition_rows = self._run(
            lambda: self.client.table("daily_conditions")
            .select(*CONDITION_COLUMNS, "planned_activities")
            .eq("user_id", wife_user_id)
            .eq("date", target_date.isoformat())
            .limit(1)
            .execute()
        )
        if not condition_rows:
            return None
        condition = condition_rows[0]

        item_rows = self._run(
            lambda: self.client.table("routine_items")
            .select("category,title,sort_order")
            .eq("user_id", wife_user_id)
            .eq("date", target_date.isoformat())
            .order("sort_order")
            .execute()
        )

        return MorningReportResponse(
            target_date=target_date,
            pregnancy_week=week,
            condition_summary=_summarize_condition(condition),
            planned_activities=condition.get("planned_activities") or [],
            guide_summaries=_summarize_guides(item_rows),
        )

    def _linked_wife_id(self, husband_user_id: str) -> str:
        link_rows = self._run(
            lambda: self.client.table("partner_links")
            .select("wife_user_id")
            .eq("husband_user_id", husband_user_id)
            .limit(1)
            .execute()
        )
        if not link_rows:
            raise DomainForbiddenError("연동된 아내 계정이 없습니다.")
        return link_rows[0]["wife_user_id"]

    def _run(self, request: Callable[[], Any]) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("오전 리포트 저장소에 연결할 수 없습니다.") from error

    # --- 그 외 Family 메서드: 지원 테이블이 아직 없어 Stub에 위임 ---

    def get_partner(self, wife_user_id: str):
        return self.fallback.get_partner(wife_user_id)

    def create_request(self, wife_user_id, wife_display_name, partner, payload):
        return self.fallback.create_request(wife_user_id, wife_display_name, partner, payload)

    def get_request(self, request_id: str):
        return self.fallback.get_request(request_id)

    def request_owner_ids(self, request_id: str):
        return self.fallback.request_owner_ids(request_id)

    def save_request(self, request) -> None:
        self.fallback.save_request(request)

    def list_requests(self, user_id: str):
        return self.fallback.list_requests(user_id)

    def add_notification(self, recipient_user_id: str, notification) -> None:
        self.fallback.add_notification(recipient_user_id, notification)

    def list_notifications(self, recipient_user_id: str):
        return self.fallback.list_notifications(recipient_user_id)

    def read_notification(self, recipient_user_id: str, notification_id: str, read_at):
        return self.fallback.read_notification(recipient_user_id, notification_id, read_at)

    def get_motion_privacy(self, user_id: str) -> MotionPrivacyResponse:
        rows = self._run(
            lambda: self.client.table("motion_consents")
            .select("consent_granted,collection_enabled,updated_at")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if not rows:
            # 아직 한 번도 동의하지 않은 상태 — 행이 없는 것 자체가 "미동의"다.
            return MotionPrivacyResponse(
                consent_granted=False,
                collection_enabled=False,
                updated_at=datetime.now(timezone.utc),
            )
        row = rows[0]
        return MotionPrivacyResponse(
            consent_granted=row["consent_granted"],
            collection_enabled=row["collection_enabled"],
            updated_at=row["updated_at"],
        )

    def save_motion_privacy(
        self, user_id: str, value: MotionPrivacyResponse
    ) -> MotionPrivacyResponse:
        row = {
            "user_id": user_id,
            "consent_granted": value.consent_granted,
            "collection_enabled": value.collection_enabled,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        rows = self._run(
            lambda: self.client.table("motion_consents")
            .upsert(row, on_conflict="user_id", default_to_null=False)
            .execute()
        )
        saved = rows[0]
        return MotionPrivacyResponse(
            consent_granted=saved["consent_granted"],
            collection_enabled=saved["collection_enabled"],
            updated_at=saved["updated_at"],
        )


def _summarize_condition(condition: dict[str, Any]) -> list[str]:
    """원본 1~5 점수를 남편에게 그대로 보여주지 않고 "높음"만 정성 문구로 뽑는다
    (임계값 3 초과, 04_3 #2처럼 계산식 미확정 항목과 같은 이유로 임시 규칙)."""
    return [
        f"{label} 높음"
        for column, label in _BURDEN_LABELS_KO.items()
        if condition.get(column, 0) > _MID
    ]


def _summarize_guides(item_rows: list[dict[str, Any]]) -> dict[str, str]:
    """카테고리별 항목 제목만 묶는다 — 원본 payload(이유·근거 등)는 넣지 않는다."""
    by_category: dict[str, list[str]] = {}
    for row in item_rows:
        by_category.setdefault(row["category"], []).append(row["title"])
    return {category: ", ".join(titles) for category, titles in by_category.items()}
