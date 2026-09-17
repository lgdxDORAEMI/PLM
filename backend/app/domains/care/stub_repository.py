from datetime import date, datetime, timezone
from uuid import uuid4

from app.domains.errors import DomainConflictError, DomainNotFoundError

from .repository import CareRepository
from .schemas import (
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
)


class StubCareRepository(CareRepository):
    """Care 계약 검증용 메모리 Stub. 프로세스 재시작 시 데이터가 초기화된다."""

    def __init__(self) -> None:
        self._conditions: dict[tuple[str, date], ConditionResponse] = {}
        self._reports: dict[tuple[str, date], DailyReportResponse] = {}
        self._executions: dict[tuple[str, str], RoutineExecutionResponse] = {}

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
        self, user_id: str, routine_item_id: str, payload: RoutineExecutionInput
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
                "completed_by": CompletionActor.WIFE if completed else None,
                "completed_at": datetime.now(timezone.utc) if completed else None,
            }
        )
        self._executions[key] = response
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
