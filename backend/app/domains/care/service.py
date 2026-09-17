from datetime import date, datetime, timezone
from typing import Protocol

from app.domains.errors import DomainNotFoundError

from .repository import CareRepository
from .schemas import (
    CalendarDay,
    CalendarMonthResponse,
    ConditionIndex,
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
        existing = self.repository.get_report(user_id, target_date)
        if existing is not None:
            return existing
        return self.repository.save_report(
            user_id, self.repository.build_report(user_id, target_date)
        )

    def finalize_report(self, user_id: str, target_date: date) -> DailyReportResponse:
        report = self.preview_report(user_id, target_date)
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
        reports = self.repository.list_reports(user_id, month)
        return CalendarMonthResponse(
            month=month,
            days=[
                CalendarDay(
                    target_date=report.target_date,
                    condition_index=ConditionIndex.FAIR,
                    has_report=True,
                    report_finalized=report.finalized,
                )
                for report in reports
            ],
        )
