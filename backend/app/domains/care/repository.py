from datetime import date
from typing import Protocol

from .schemas import (
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


class CareRepository(Protocol):
    """Care 영속화 adapter의 최소 계약. Routine 생성 구현에는 의존하지 않는다."""

    def get_condition(self, user_id: str, target_date: date) -> ConditionResponse | None: ...

    def save_condition(
        self, user_id: str, target_date: date, payload: ConditionInput
    ) -> ConditionResponse: ...

    def save_activities(
        self, user_id: str, target_date: date, payload: PlannedActivitiesInput
    ) -> ConditionResponse: ...

    def set_execution(
        self, user_id: str, routine_item_id: str, payload: RoutineExecutionInput
    ) -> RoutineExecutionResponse: ...

    def update_routine_item(
        self, user_id: str, routine_item_id: str, payload: RoutineItemUpdateInput
    ) -> RoutineItemResponse: ...

    def update_sleep_environment(
        self, user_id: str, routine_item_id: str, payload: SleepEnvironmentInput
    ) -> RoutineItemResponse: ...

    def get_report(self, user_id: str, target_date: date) -> DailyReportResponse | None: ...

    def build_report(self, user_id: str, target_date: date) -> DailyReportResponse: ...

    def save_report(
        self, user_id: str, report: DailyReportResponse
    ) -> DailyReportResponse: ...

    def list_reports(self, user_id: str, month: str) -> list[DailyReportResponse]: ...
