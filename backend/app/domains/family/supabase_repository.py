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

"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Callable

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainForbiddenError, DomainStorageError
from app.utils import dates

from .repository import FamilyRepository, PartnerIdentity
from .schemas import (
    HouseholdDailySummary,
    HouseholdRequestCreate,
    HouseholdRequestItem,
    HouseholdRequestResponse,
    MorningReportResponse,
    MotionPrivacyResponse,
    NotificationResponse,
)

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
            .select("category,title,sort_order,change_kind")
            .eq("user_id", wife_user_id)
            .eq("date", target_date.isoformat())
            .order("sort_order")
            .execute()
        )
        # 재생성 시 FK(household_request_items/chat_messages/recommendation_feedback)가
        # 삭제를 막으면 삭제 대신 change_kind='removed'로만 남는다(routine/repository.py
        # _sync_items) — 더 이상 오늘 루틴이 아니므로 요약에서 뺀다. SQL .neq()는
        # NULL(대부분의 정상 행)까지 걸러내므로 Python에서 비교한다.
        item_rows = [row for row in item_rows if row.get("change_kind") != "removed"]

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

    def get_partner(self, wife_user_id: str) -> PartnerIdentity | None:
        link_rows = self._run(
            lambda: self.client.table("partner_links")
            .select("husband_user_id")
            .eq("wife_user_id", wife_user_id)
            .limit(1)
            .execute()
        )
        if not link_rows:
            return None
        husband_id = link_rows[0]["husband_user_id"]
        profile_rows = self._run(
            lambda: self.client.table("profiles")
            .select("display_name")
            .eq("user_id", husband_id)
            .limit(1)
            .execute()
        )
        display_name = profile_rows[0]["display_name"] if profile_rows else "남편"
        return PartnerIdentity(user_id=husband_id, display_name=display_name)

    def create_request(
        self,
        wife_user_id: str,
        wife_display_name: str,
        partner: PartnerIdentity,
        payload: HouseholdRequestCreate,
    ) -> HouseholdRequestResponse:
        request_rows = self._run(
            lambda: self.client.table("household_requests")
            .insert(
                {
                    "wife_user_id": wife_user_id,
                    "husband_user_id": partner.user_id,
                    "date": payload.target_date.isoformat(),
                    "reason_text": payload.reason,
                }
            )
            .execute()
        )
        row = request_rows[0]
        item_rows = self._run(
            lambda: self.client.table("household_request_items")
            .insert(
                [
                    {
                        "request_id": row["id"],
                        "routine_item_id": item.routine_item_id,
                        "title": item.title,
                        "helper_info": item.helper_info,
                    }
                    for item in payload.items
                ]
            )
            .execute()
        )
        daily_summary = self._daily_summary(wife_user_id, payload.target_date)
        return _build_response(
            row, item_rows, wife_display_name, partner.display_name, daily_summary
        )

    def get_request(self, request_id: str) -> HouseholdRequestResponse | None:
        rows = self._run(
            lambda: self.client.table("household_requests")
            .select("*")
            .eq("id", request_id)
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        return self._load_response(rows[0])

    def request_owner_ids(self, request_id: str) -> tuple[str, str] | None:
        rows = self._run(
            lambda: self.client.table("household_requests")
            .select("wife_user_id,husband_user_id")
            .eq("id", request_id)
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        return (rows[0]["wife_user_id"], rows[0]["husband_user_id"])

    def save_request(self, request: HouseholdRequestResponse) -> None:
        self._run(
            lambda: self.client.table("household_requests")
            .update(
                {
                    "status": request.status,
                    "confirmed_at": _iso(request.confirmed_at),
                    "completed_at": _iso(request.completed_at),
                }
            )
            .eq("id", request.request_id)
            .execute()
        )
        for item in request.items:
            self._run(
                lambda item=item: self.client.table("household_request_items")
                .update({"status": item.status})
                .eq("id", item.item_id)
                .execute()
            )

    def list_requests(self, user_id: str) -> list[HouseholdRequestResponse]:
        as_wife = self._run(
            lambda: self.client.table("household_requests")
            .select("*")
            .eq("wife_user_id", user_id)
            .execute()
        )
        as_husband = self._run(
            lambda: self.client.table("household_requests")
            .select("*")
            .eq("husband_user_id", user_id)
            .execute()
        )
        return [self._load_response(row) for row in as_wife + as_husband]

    def _load_response(self, row: dict[str, Any]) -> HouseholdRequestResponse:
        item_rows = self._run(
            lambda: self.client.table("household_request_items")
            .select("*")
            .eq("request_id", row["id"])
            .execute()
        )
        husband_rows = self._run(
            lambda: self.client.table("profiles")
            .select("display_name")
            .eq("user_id", row["husband_user_id"])
            .limit(1)
            .execute()
        )
        husband_name = husband_rows[0]["display_name"] if husband_rows else "남편"
        daily_summary = self._daily_summary(
            row["wife_user_id"], date.fromisoformat(str(row["date"]))
        )
        return _build_response(row, item_rows, "아내", husband_name, daily_summary)

    def _daily_summary(
        self, wife_user_id: str, target_date: date
    ) -> HouseholdDailySummary:
        """해당 날짜에 아내가 보낸 모든 요청의 항목(item) 개수를 status별로 합산한다.
        `household_requests`의 (wife_user_id, date)는 유니크가 아니라 인덱스일
        뿐이라 하루에 여러 건이 있을 수 있다 — 건수(row)가 아니라 항목(item)
        개수를 세야 해서 care/supabase_repository.py의 _family_summary()는
        재사용하지 않는다."""
        request_rows = self._run(
            lambda: self.client.table("household_requests")
            .select("id,status")
            .eq("wife_user_id", wife_user_id)
            .eq("date", target_date.isoformat())
            .execute()
        )
        if not request_rows:
            return HouseholdDailySummary(requested=0, confirmed=0, completed=0)

        request_ids = [row["id"] for row in request_rows]
        item_rows = self._run(
            lambda: self.client.table("household_request_items")
            .select("request_id")
            .in_("request_id", request_ids)
            .execute()
        )
        item_counts: dict[str, int] = {}
        for item in item_rows:
            item_counts[item["request_id"]] = item_counts.get(item["request_id"], 0) + 1

        requested = confirmed = completed = 0
        for row in request_rows:
            count = item_counts.get(row["id"], 0)
            requested += count
            if row["status"] in ("confirmed", "completed"):
                confirmed += count
            if row["status"] == "completed":
                completed += count
        return HouseholdDailySummary(
            requested=requested, confirmed=confirmed, completed=completed
        )

    def add_notification(
        self, recipient_user_id: str, notification: NotificationResponse
    ) -> None:
        self._run(
            lambda: self.client.table("notifications")
            .insert(
                {
                    "recipient_user_id": recipient_user_id,
                    "type": notification.type,
                    "reference_id": notification.reference_id,
                    "target_date": (
                        notification.target_date.isoformat()
                        if notification.target_date
                        else None
                    ),
                    "title": notification.title,
                    "body": notification.body,
                }
            )
            .execute()
        )

    def list_notifications(self, recipient_user_id: str) -> list[NotificationResponse]:
        rows = self._run(
            lambda: self.client.table("notifications")
            .select("*")
            .eq("recipient_user_id", recipient_user_id)
            .order("created_at", desc=True)
            .execute()
        )
        return [_build_notification(row) for row in rows]

    def read_notification(
        self, recipient_user_id: str, notification_id: str, read_at: datetime
    ) -> NotificationResponse | None:
        rows = self._run(
            lambda: self.client.table("notifications")
            .update({"read_at": read_at.isoformat()})
            .eq("id", notification_id)
            .eq("recipient_user_id", recipient_user_id)
            .execute()
        )
        if not rows:
            return None
        return _build_notification(rows[0])

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


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _build_response(
    row: dict[str, Any],
    item_rows: list[dict[str, Any]],
    wife_display_name: str,
    husband_display_name: str,
    daily_summary: HouseholdDailySummary,
) -> HouseholdRequestResponse:
    return HouseholdRequestResponse(
        request_id=row["id"],
        target_date=date.fromisoformat(str(row["date"])),
        requester_display_name=wife_display_name,
        recipient_display_name=husband_display_name,
        reason=row["reason_text"],
        status=row["status"],
        items=[
            HouseholdRequestItem(
                item_id=item["id"],
                title=item["title"],
                helper_info=item.get("helper_info"),
                routine_item_id=item.get("routine_item_id"),
                status=item["status"],
            )
            for item in item_rows
        ],
        requested_at=row["requested_at"],
        confirmed_at=row.get("confirmed_at"),
        completed_at=row.get("completed_at"),
        daily_summary=daily_summary,
    )


def _build_notification(row: dict[str, Any]) -> NotificationResponse:
    return NotificationResponse(
        notification_id=row["id"],
        type=row["type"],
        title=row["title"],
        body=row["body"],
        target_date=date.fromisoformat(str(row["target_date"])) if row.get("target_date") else None,
        reference_id=row["reference_id"],
        created_at=row["created_at"],
        read_at=row.get("read_at"),
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
