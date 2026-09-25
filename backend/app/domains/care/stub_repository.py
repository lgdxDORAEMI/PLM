from datetime import date, datetime, timezone
from uuid import uuid4

from app.domains.errors import DomainConflictError, DomainNotFoundError

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
    RoutineCategory,
    RoutineExecutionInput,
    RoutineExecutionResponse,
    RoutineItemResponse,
    RoutineItemUpdateInput,
    SleepEnvironmentInput,
    condition_index_from_scores,
)


class StubCareRepository(CareRepository):
    """Care 계약 검증용 메모리 Stub. 프로세스 재시작 시 데이터가 초기화된다."""

    def __init__(self) -> None:
        self._conditions: dict[tuple[str, date], ConditionResponse] = {}
        self._reports: dict[tuple[str, date], DailyReportResponse] = {}
        self._executions: dict[tuple[str, str], RoutineExecutionResponse] = {}
        self._routine_item_overrides: dict[tuple[str, str], RoutineItemResponse] = {}

    def reset_daily_experience(self, user_id: str, target_date: date) -> None:
        """Keep the in-memory care stub aligned with the reset contract."""
        self._conditions.pop((user_id, target_date), None)
        self._reports.pop((user_id, target_date), None)

    def get_condition(self, user_id: str, target_date: date) -> ConditionResponse | None:
        return self._conditions.get((user_id, target_date))

    def save_condition(
        self, user_id: str, target_date: date, payload: ConditionInput
    ) -> ConditionResponse:
        key = (user_id, target_date)
        previous = self._conditions.get(key)
        values = payload.model_dump()
        changed_fields = (
            []
            if previous is None
            else [name for name, value in values.items() if getattr(previous, name) != value]
        )
        finalized = self._reports.get(key)
        write_kind = (
            ConditionWriteKind.NEW_ROUTINE_REQUIRED
            if finalized is not None and finalized.finalized
            else ConditionWriteKind.UPDATED
            if previous is not None
            else ConditionWriteKind.CREATED
        )
        response = ConditionResponse(
            **values,
            target_date=target_date,
            planned_activities=previous.planned_activities if previous else [],
            changed_fields=changed_fields,
            write_kind=write_kind,
            updated_at=datetime.now(timezone.utc),
        )
        self._conditions[key] = response
        return response

    def save_activities(
        self, user_id: str, target_date: date, payload: PlannedActivitiesInput
    ) -> ConditionResponse:
        key = (user_id, target_date)
        condition = self._conditions.get(key)
        if condition is None:
            raise DomainConflictError("해당 날짜의 컨디션을 먼저 저장해 주세요.")
        response = condition.model_copy(
            update={
                "planned_activities": payload.activities,
                "updated_at": datetime.now(timezone.utc),
            }
        )
        self._conditions[key] = response
        return response

    def set_execution(
        self,
        user_id: str,
        routine_item_id: str,
        payload: RoutineExecutionInput,
        *,
        actor: CompletionActor = CompletionActor.WIFE,
    ) -> RoutineExecutionResponse:
        key = (user_id, routine_item_id)
        previous = self._executions.get(key)
        if previous is None:
            previous = RoutineExecutionResponse(
                routine_item_id=routine_item_id,
                category=RoutineCategory.HEALTH,
                title="Stub 루틴 항목",
                status=ExecutionStatus.SCHEDULED,
            )
        completed = payload.status == ExecutionStatus.COMPLETED
        response = previous.model_copy(
            update={
                "status": payload.status,
                "completed_by": actor if completed else None,
                "completed_at": datetime.now(timezone.utc) if completed else None,
            }
        )
        self._executions[key] = response
        return response

    def update_routine_item(
        self, user_id: str, routine_item_id: str, payload: RoutineItemUpdateInput
    ) -> RoutineItemResponse:
        # Stub은 실제 routine_items 원본을 모른다 — category/title을 지어내지 않고
        # 요청으로 받은 payload만 그대로 반영한다(NFR-014 성격의 최소 응답 원칙).
        response = RoutineItemResponse(
            routine_item_id=routine_item_id,
            category=RoutineCategory.MEAL,
            title=None,
            payload=payload.payload,
        )
        self._routine_item_overrides[(user_id, routine_item_id)] = response
        return response

    def update_sleep_environment(
        self, user_id: str, routine_item_id: str, payload: SleepEnvironmentInput
    ) -> RoutineItemResponse:
        response = RoutineItemResponse(
            routine_item_id=routine_item_id,
            category=RoutineCategory.SLEEP,
            title=None,
            payload={
                key: value
                for key, value in payload.model_dump().items()
                if value is not None
            },
        )
        self._routine_item_overrides[(user_id, routine_item_id)] = response
        return response

    def get_report(self, user_id: str, target_date: date) -> DailyReportResponse | None:
        return self._reports.get((user_id, target_date))

    def save_report(
        self, user_id: str, report: DailyReportResponse
    ) -> DailyReportResponse:
        self._reports[(user_id, report.target_date)] = report
        return report

    def list_reports(self, user_id: str, month: str) -> list[DailyReportResponse]:
        return [
            report
            for (owner_id, target_date), report in self._reports.items()
            if owner_id == user_id and target_date.strftime("%Y-%m") == month
        ]

    def list_calendar_days(self, user_id: str, month: str) -> list[CalendarDay]:
        finalized_dates = {
            target_date
            for (owner_id, target_date), report in self._reports.items()
            if owner_id == user_id and report.finalized and target_date.strftime("%Y-%m") == month
        }
        return [
            CalendarDay(
                target_date=target_date,
                condition_index=condition_index_from_scores(condition.model_dump()),
                has_report=target_date in finalized_dates,
                report_finalized=target_date in finalized_dates,
            )
            for (owner_id, target_date), condition in self._conditions.items()
            if owner_id == user_id and target_date.strftime("%Y-%m") == month
        ]

    def build_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        if self.get_condition(user_id, target_date) is None:
            raise DomainNotFoundError("해당 날짜에 집계할 컨디션 기록이 없습니다.")
        routines = [
            execution
            for (owner_id, _), execution in self._executions.items()
            if owner_id == user_id
        ]
        return DailyReportResponse(
            report_id=str(uuid4()),
            target_date=target_date,
            finalized=False,
            completed_routines=sum(
                item.status == ExecutionStatus.COMPLETED for item in routines
            ),
            appliance_executions=0,
            routines=routines,
            family=FamilyContributionSummary(requested=0, confirmed=0, completed=0),
            updated_at=datetime.now(timezone.utc),
        )
