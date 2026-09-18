"""Care 도메인의 Condition(STEP 9) + Record/Report/Calendar(STEP 12)를 실제 DB에
연결한다. routine-item 피드백(수면 환경 override, 메뉴 피드백)만 지원 테이블
(recommendation_feedback)이 아직 없어 fallback(Stub)에 위임한다 —
BACKEND_COLLABORATION.md "테이블 단위로 쪼개 진행" 원칙.

STEP 12 원칙:
- Record는 `routine_items.status/completed_by/completed_at`을 SOURCE로 직접
  갱신한다. 별도 실행 로그 테이블을 만들지 않는다(DATA_OWNERSHIP.md Duplicate
  Storage 항목 3).
- Report(`daily_reports`)는 원본을 복제 저장하지 않는다. Record(routine_items)·
  Condition(daily_conditions 존재 확인)·Movement(posture_events, Protected
  `app/services/movement/report.py`의 `generate_daily_report()`를 그대로 호출해
  재사용 — 새로 만들지 않음)에서 매번 계산한 결과만 `content`에 담는다.
- 미리보기는 저장하지 않는다(NFR-028, 날짜당 1개). `daily_reports`에 행이
  생기는 시점은 확정(finalize) 뿐이다 — `finalized` 컬럼 없이 "행이 있으면
  확정된 것"으로 단순화했다.
- Calendar는 테이블이 아니라 daily_conditions+daily_reports 조합 조회다.

컬럼 이름은 `app/services/routine/inputs.py`(Protected)의 CONDITION_COLUMNS와
반드시 맞춘다 — Routine Generator가 이 테이블을 그대로 읽는다.
"""

from __future__ import annotations

import calendar as calendar_module
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any, Callable
from uuid import UUID, uuid4

_ONE_DAY = timedelta(days=1)

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainConflictError, DomainNotFoundError, DomainStorageError
from app.services.movement.events import EventStorageError, SupabaseEventStore
from app.services.movement.report import generate_daily_report
from app.services.supabase_service import SupabaseService

from .repository import CareRepository
from .schemas import (
    CalendarDay,
    CompletionActor,
    ConditionInput,
    ConditionResponse,
    ConditionWriteKind,
    DailyReportResponse,
    ExecutionStatus,
    FamilyContributionSummary,
    PlannedActivitiesInput,
    RoutineExecutionInput,
    RoutineExecutionResponse,
    condition_index_from_scores,
)

logger = logging.getLogger(__name__)

TABLE = "daily_conditions"
ROUTINE_ITEMS_TABLE = "routine_items"
REPORTS_TABLE = "daily_reports"
REPORT_KIND = "daily"  # 이 Repository는 W-REPORT-001(Daily)만 다룬다. 오전 리포트(kind=morning)는 family 도메인 소관.
HOUSEHOLD_REQUESTS_TABLE = "household_requests"
_CONFIRMED_OR_FURTHER = {"confirmed", "completed"}

EXECUTION_COLUMNS = ("id", "category", "title", "status", "completed_by", "completed_at")

# routine/inputs.py의 CONDITION_COLUMNS 중 아내가 직접 입력하는 7개 점수만.
# sleep_quality는 화면(W-COND-001)에 아직 없고 척도도 미확정(04_3 #2)이라 이 API는
# 건드리지 않는다 — 컬럼은 nullable로 그대로 두고 Routine이 null을 그대로 읽는다.
SCORE_COLUMNS = (
    "nausea",
    "waist_pain",
    "pelvis_pain",
    "leg_pain",
    "wrist_pain",
    "fatigue",
    "mood",
)
SELECT_COLUMNS = SCORE_COLUMNS + ("planned_activities", "updated_at")

Row = dict[str, Any]


class SupabaseCareRepository(CareRepository):
    def __init__(self, client: Client, fallback: CareRepository) -> None:
        self.client = client
        self.fallback = fallback

    # --- Condition: 실제 daily_conditions 연결 ---

    def get_condition(self, user_id: str, target_date: date) -> ConditionResponse | None:
        rows = self._run(
            lambda: self.client.table(TABLE)
            .select(*SELECT_COLUMNS)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        # 조회는 아무것도 "쓰지" 않으므로 changed_fields는 비우고, write_kind는 조회에는
        # 의미가 없어 중립값(UPDATED)을 둔다 — 실제로 무언가 바뀐 것처럼 지어내지 않는다.
        return _to_response(
            rows[0], target_date, write_kind=ConditionWriteKind.UPDATED, changed_fields=[]
        )

    def save_condition(
        self, user_id: str, target_date: date, payload: ConditionInput
    ) -> ConditionResponse:
        previous_rows = self._run(
            lambda: self.client.table(TABLE)
            .select(*SCORE_COLUMNS)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .limit(1)
            .execute()
        )
        previous = previous_rows[0] if previous_rows else None
        values = payload.model_dump()
        changed_fields = (
            []
            if previous is None
            else [name for name, value in values.items() if previous.get(name) != value]
        )
        row = {"user_id": user_id, "date": target_date.isoformat(), **values, "updated_at": _now()}
        # default_to_null=False: planned_activities처럼 이 요청에 없는 컬럼을
        # null로 덮어쓰지 않는다(save_due_date와 같은 이유).
        rows = self._run(
            lambda: self.client.table(TABLE)
            .upsert(row, on_conflict="user_id,date", default_to_null=False)
            .execute()
        )
        # FUC-W-COND-004(확정된 리포트가 있으면 NEW_ROUTINE_REQUIRED)는 daily_reports
        # 실 연동이 아직 없어(Report 도메인은 별도 STEP) 이번 구현 범위에서 판단하지
        # 않는다 — CREATED/UPDATED만 정확히 구분한다. TBD.
        write_kind = ConditionWriteKind.CREATED if previous is None else ConditionWriteKind.UPDATED
        return _to_response(
            rows[0], target_date, write_kind=write_kind, changed_fields=changed_fields
        )

    def save_activities(
        self, user_id: str, target_date: date, payload: PlannedActivitiesInput
    ) -> ConditionResponse:
        # update()는 행이 없으면 빈 리스트를 돌려준다 — 컨디션을 먼저 저장했는지 여부를
        # 이걸로 판단한다(profile_service.save_body와 같은 전제).
        rows = self._run(
            lambda: self.client.table(TABLE)
            .update({"planned_activities": payload.activities, "updated_at": _now()})
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .execute()
        )
        if not rows:
            raise DomainConflictError("해당 날짜의 컨디션을 먼저 저장해 주세요.")
        return _to_response(
            rows[0],
            target_date,
            write_kind=ConditionWriteKind.UPDATED,
            changed_fields=["planned_activities"],
        )

    def _run(self, request: Callable[[], Any]) -> list[Row]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            raise DomainStorageError("컨디션 저장소에 연결할 수 없습니다.") from error

    # --- Record: routine_items.status/completed_by/completed_at 직접 갱신 ---
    # 별도 실행 로그 테이블을 만들지 않는다 — routine_items 자체가 SOURCE다.

    def set_execution(
        self, user_id: str, routine_item_id: str, payload: RoutineExecutionInput
    ) -> RoutineExecutionResponse:
        if payload.status == ExecutionStatus.NEEDS_CONFIRMATION:
            # routine_items.status는 DB CHECK로 scheduled/completed/skipped만 허용한다
            # (Protected migration). needs_confirmation은 화면 계약에는 있지만 저장
            # 가능한 상태가 아직 정의되지 않았다 — TBD, 여기서는 명확히 거절한다.
            raise DomainConflictError("이 상태는 아직 저장할 수 없습니다.")
        completed = payload.status == ExecutionStatus.COMPLETED
        values = {
            "status": payload.status.value,
            "completed_by": CompletionActor.WIFE.value if completed else None,
            "completed_at": _now() if completed else None,
        }
        rows = self._run(
            lambda: self.client.table(ROUTINE_ITEMS_TABLE)
            .update(values)
            .eq("id", routine_item_id)
            .eq("user_id", user_id)
            .execute()
        )
        if not rows:
            raise DomainNotFoundError("루틴 항목을 찾을 수 없습니다.")
        row = rows[0]
        return RoutineExecutionResponse(
            routine_item_id=row["id"],
            category=row["category"],
            title=row["title"],
            status=row["status"],
            completed_by=row.get("completed_by"),
            completed_at=row.get("completed_at"),
        )

    # --- routine-item 피드백(수면 환경 override, 메뉴 피드백)은 지원 테이블
    # (recommendation_feedback)이 아직 없어 Stub에 위임한다. STEP 12 범위 밖. ---

    def update_routine_item(self, user_id, routine_item_id, payload):
        return self.fallback.update_routine_item(user_id, routine_item_id, payload)

    def update_sleep_environment(self, user_id, routine_item_id, payload):
        return self.fallback.update_sleep_environment(user_id, routine_item_id, payload)

    # --- Report: daily_reports에는 계산 결과만 담는다. 미리보기는 저장하지 않는다 ---

    def get_report(self, user_id: str, target_date: date) -> DailyReportResponse | None:
        rows = self._run(
            lambda: self.client.table(REPORTS_TABLE)
            .select("id,content,created_at")
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .eq("kind", REPORT_KIND)
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        row = rows[0]
        return DailyReportResponse(
            report_id=row["id"],
            target_date=target_date,
            # 이 테이블에 행이 있다는 것 자체가 확정됐다는 뜻이다 — 미리보기는
            # daily_reports에 아예 쓰지 않으므로(NFR-028) 별도 finalized 컬럼이 없다.
            finalized=True,
            updated_at=row["created_at"],
            **row["content"],
        )

    def build_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        content = self._compute_report_content(user_id, target_date)
        return DailyReportResponse(
            report_id=str(uuid4()),  # 미저장 미리보기용 임시 id
            target_date=target_date,
            finalized=False,
            updated_at=datetime.now(timezone.utc),
            **content,
        )

    def save_report(self, user_id: str, report: DailyReportResponse) -> DailyReportResponse:
        """Service의 finalize_report에서만 호출된다 — daily_reports에 쓰는 유일한 경로."""
        content = report.model_dump(
            mode="json", exclude={"report_id", "target_date", "finalized", "updated_at"}
        )
        row = {
            "user_id": user_id,
            "date": report.target_date.isoformat(),
            "kind": REPORT_KIND,
            "content": content,
        }
        rows = self._run(
            lambda: self.client.table(REPORTS_TABLE)
            .upsert(row, on_conflict="user_id,date,kind", default_to_null=False)
            .execute()
        )
        saved = rows[0]
        return report.model_copy(
            update={"report_id": saved["id"], "finalized": True}
        )

    def list_reports(self, user_id, month):
        return self.fallback.list_reports(user_id, month)

    # --- Calendar: 저장 없이 daily_conditions + daily_reports 조합 조회 ---

    def list_calendar_days(self, user_id: str, month: str) -> list[CalendarDay]:
        start, end = _month_bounds(month)
        condition_rows = self._run(
            lambda: self.client.table(TABLE)
            .select("date", *SCORE_COLUMNS)
            .eq("user_id", user_id)
            .gte("date", start.isoformat())
            .lt("date", end.isoformat())
            .execute()
        )
        report_rows = self._run(
            lambda: self.client.table(REPORTS_TABLE)
            .select("date")
            .eq("user_id", user_id)
            .eq("kind", REPORT_KIND)
            .gte("date", start.isoformat())
            .lt("date", end.isoformat())
            .execute()
        )
        finalized_dates = {row["date"] for row in report_rows}
        return [
            CalendarDay(
                target_date=date.fromisoformat(str(row["date"])),
                condition_index=condition_index_from_scores(
                    {column: row[column] for column in SCORE_COLUMNS}
                ),
                has_report=row["date"] in finalized_dates,
                report_finalized=row["date"] in finalized_dates,
            )
            for row in condition_rows
        ]

    def _compute_report_content(self, user_id: str, target_date: date) -> dict[str, Any]:
        """Record(routine_items)·Condition(존재 확인)·Movement(재사용)에서만
        파생한다 — 원본을 복제 저장하지 않는다."""
        condition_rows = self._run(
            lambda: self.client.table(TABLE)
            .select("user_id")
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .limit(1)
            .execute()
        )
        if not condition_rows:
            raise DomainNotFoundError("해당 날짜에 집계할 컨디션 기록이 없습니다.")

        item_rows = self._run(
            lambda: self.client.table(ROUTINE_ITEMS_TABLE)
            .select(*EXECUTION_COLUMNS)
            .eq("user_id", user_id)
            .eq("date", target_date.isoformat())
            .execute()
        )
        routines = [
            RoutineExecutionResponse(
                routine_item_id=row["id"],
                category=row["category"],
                title=row["title"],
                status=row["status"],
                completed_by=row.get("completed_by"),
                completed_at=row.get("completed_at"),
            )
            for row in item_rows
        ]
        completed_routines = sum(1 for r in routines if r.status == ExecutionStatus.COMPLETED)
        appliance_executions = sum(
            1 for r in routines if r.completed_by == CompletionActor.APPLIANCE
        )
        highest_load_area, motion_cautions = self._movement_summary(user_id, target_date)

        return {
            "completed_routines": completed_routines,
            "appliance_executions": appliance_executions,
            "routines": routines,
            "highest_load_area": highest_load_area,
            "motion_cautions": motion_cautions,
            "family": self._family_summary(user_id, target_date),
        }

    def _family_summary(self, user_id: str, target_date: date) -> FamilyContributionSummary:
        """가사 요청(Household, family 도메인 소유 테이블)에서 그 날짜 분담
        현황만 센다 — 원본을 복제하지 않고 직접 조회한다(오전 리포트가 Care
        테이블을 그 자리에서 읽는 projection과 같은 방식). status는
        unconfirmed→confirmed→completed로만 전이하므로 누적(funnel)
        집계다: confirmed/completed는 "적어도 그 단계까지 간" 개수다."""
        rows = self._run(
            lambda: self.client.table(HOUSEHOLD_REQUESTS_TABLE)
            .select("status")
            .eq("wife_user_id", user_id)
            .eq("date", target_date.isoformat())
            .execute()
        )
        return FamilyContributionSummary(
            requested=len(rows),
            confirmed=sum(1 for row in rows if row["status"] in _CONFIRMED_OR_FURTHER),
            completed=sum(1 for row in rows if row["status"] == "completed"),
        )

    def _movement_summary(self, user_id: str, target_date: date) -> tuple[str | None, list[str]]:
        """Movement(Protected)가 이미 만든 generate_daily_report()를 그대로
        재사용한다 — 카테고리별 재계산이 아니라 Movement 산출물을 읽기만 한다."""
        try:
            event_store = SupabaseEventStore(_ClientHolder(self.client))
            summary = generate_daily_report(event_store, UUID(user_id), target_date)
        except (EventStorageError, ValueError):
            # 모션 데이터는 Report의 핵심이 아니라 보강 정보다(NFR-017: 외부 시스템
            # 장애가 핵심 기능을 막지 않아야 한다) — 실패해도 리포트는 계속 만든다.
            logger.info("모션 데이터 조회 실패, 리포트는 모션 요약 없이 진행")
            return None, []
        highest_load_area = (
            summary.top_burdened_body_part.value if summary.top_burdened_body_part else None
        )
        return highest_load_area, summary.narratives


class _ClientHolder:
    """SupabaseEventStore가 기대하는 `.client` 프로퍼티만 흉내 내는 얇은 어댑터.
    이 Repository는 이미 해석된 Client를 들고 있어 SupabaseService 전체가
    필요 없다 — 그렇다고 movement/events.py(Protected)의 생성자 계약을 바꾸지도
    않는다."""

    def __init__(self, client: Client) -> None:
        self.client = client


def _month_bounds(month: str) -> tuple[date, date]:
    year_str, month_str = month.split("-")
    year, mon = int(year_str), int(month_str)
    start = date(year, mon, 1)
    days_in_month = calendar_module.monthrange(year, mon)[1]
    end = date(year, mon, days_in_month) + _ONE_DAY
    return start, end


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _to_response(
    row: Row,
    target_date: date,
    *,
    write_kind: ConditionWriteKind,
    changed_fields: list[str],
) -> ConditionResponse:
    return ConditionResponse(
        **{column: row[column] for column in SCORE_COLUMNS},
        target_date=target_date,
        planned_activities=row.get("planned_activities") or [],
        changed_fields=changed_fields,
        write_kind=write_kind,
        updated_at=row["updated_at"],
    )
