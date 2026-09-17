from datetime import date, datetime, timezone
from typing import Protocol

from app.domains.errors import DomainNotFoundError

from .repository import CareRepository
from .schemas import (
    CalendarMonthResponse,
    ConditionInput,
    ConditionResponse,
    DailyReportResponse,
    PlannedActivitiesInput,
    RoutineExecutionInput,
    RoutineExecutionResponse,
    RoutineItemResponse,
    RoutineItemUpdateInput,
    SleepEnvironmentInput,
)


class CareServicePort(Protocol):
    def get_condition(self, user_id: str, target_date: date) -> ConditionResponse: ...

    def save_condition(
        self, user_id: str, target_date: date, payload: ConditionInput
    ) -> ConditionResponse: ...

    def save_activities(
        self, user_id: str, target_date: date, payload: PlannedActivitiesInput
    ) -> ConditionResponse: ...

    def set_execution(
        self, user_id: str, item_id: str, payload: RoutineExecutionInput
    ) -> RoutineExecutionResponse: ...

    def update_routine_item(
        self, user_id: str, item_id: str, payload: RoutineItemUpdateInput
    ) -> RoutineItemResponse: ...

    def update_sleep_environment(
        self, user_id: str, item_id: str, payload: SleepEnvironmentInput
    ) -> RoutineItemResponse: ...

    def preview_report(self, user_id: str, target_date: date) -> DailyReportResponse: ...

    def finalize_report(self, user_id: str, target_date: date) -> DailyReportResponse: ...

    def get_report(self, user_id: str, target_date: date) -> DailyReportResponse: ...

    def calendar(self, user_id: str, month: str) -> CalendarMonthResponse: ...


class CareService(CareServicePort):
    def __init__(self, repository: CareRepository) -> None:
        self.repository = repository

    def get_condition(self, user_id: str, target_date: date) -> ConditionResponse:
        condition = self.repository.get_condition(user_id, target_date)
        if condition is None:
            raise DomainNotFoundError("해당 날짜의 컨디션 기록이 없습니다.")
        return condition

    def save_condition(
        self, user_id: str, target_date: date, payload: ConditionInput
    ) -> ConditionResponse:
        return self.repository.save_condition(user_id, target_date, payload)

    def save_activities(
        self, user_id: str, target_date: date, payload: PlannedActivitiesInput
    ) -> ConditionResponse:
        return self.repository.save_activities(user_id, target_date, payload)

    def set_execution(
        self, user_id: str, item_id: str, payload: RoutineExecutionInput
    ) -> RoutineExecutionResponse:
        return self.repository.set_execution(user_id, item_id, payload)

    def update_routine_item(
        self, user_id: str, item_id: str, payload: RoutineItemUpdateInput
    ) -> RoutineItemResponse:
        return self.repository.update_routine_item(user_id, item_id, payload)

    def update_sleep_environment(
        self, user_id: str, item_id: str, payload: SleepEnvironmentInput
    ) -> RoutineItemResponse:
        return self.repository.update_sleep_environment(user_id, item_id, payload)

    def preview_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        """미리보기는 저장하지 않는다 — Daily Report는 날짜당 1개만 존재해야 하므로
        (NFR-028) 확정 전 상태를 영속화하지 않는다. 이미 확정된 리포트가 있으면
        그걸 그대로 보여주고, 없으면 매번 새로 계산만 해서 보여준다."""
        existing = self.repository.get_report(user_id, target_date)
        if existing is not None:
            return existing
        return self.repository.build_report(user_id, target_date)

    def finalize_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        """저장(=Daily Report 행 생성/갱신)은 이 명시적 요청에서만 일어난다."""
        report = self.repository.build_report(user_id, target_date)
        finalized = report.model_copy(
            update={"finalized": True, "updated_at": datetime.now(timezone.utc)}
        )
        return self.repository.save_report(user_id, finalized)

    def get_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        report = self.repository.get_report(user_id, target_date)
        if report is None:
            raise DomainNotFoundError("해당 날짜의 Daily 리포트가 없습니다.")
        return report

    def calendar(self, user_id: str, month: str) -> CalendarMonthResponse:
        """Calendar는 별도 테이블이 아니라 조회 모델(VIEW)이다 — 저장은
        Repository가 daily_conditions/daily_reports를 조합해서 만든다."""
        return CalendarMonthResponse(month=month, days=self.repository.list_calendar_days(user_id, month))
