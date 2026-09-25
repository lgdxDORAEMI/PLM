from datetime import date, datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


Score = int


class ConditionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nausea: Score = Field(ge=1, le=5)
    waist_pain: Score = Field(ge=1, le=5)
    pelvis_pain: Score = Field(ge=1, le=5)
    leg_pain: Score = Field(ge=1, le=5)
    wrist_pain: Score = Field(ge=1, le=5)
    fatigue: Score = Field(ge=1, le=5)
    mood: Score = Field(ge=1, le=5)


class PlannedActivitiesInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    activities: list[str] = Field(default_factory=list, max_length=20)

    @field_validator("activities")
    @classmethod
    def normalize_activities(cls, values: list[str]) -> list[str]:
        normalized = [value.strip() for value in values if value.strip()]
        if any(len(value) > 80 for value in normalized):
            raise ValueError("예정 활동은 항목당 80자 이하여야 합니다.")
        return list(dict.fromkeys(normalized))


class ConditionWriteKind(StrEnum):
    CREATED = "created"
    UPDATED = "updated"
    NEW_ROUTINE_REQUIRED = "new_routine_required"


class ConditionResponse(ConditionInput):
    target_date: date
    planned_activities: list[str] = Field(default_factory=list)
    changed_fields: list[str] = Field(default_factory=list)
    write_kind: ConditionWriteKind
    updated_at: datetime


class RoutineCategory(StrEnum):
    MEAL = "meal"
    HOUSEHOLD = "household"
    HEALTH = "health"
    SLEEP = "sleep"


class ExecutionStatus(StrEnum):
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    SKIPPED = "skipped"
    NEEDS_CONFIRMATION = "needs_confirmation"


class CompletionActor(StrEnum):
    WIFE = "wife"
    HUSBAND = "husband"
    APPLIANCE = "appliance"


class RoutineExecutionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: ExecutionStatus


class RoutineExecutionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    routine_item_id: str
    category: RoutineCategory
    title: str
    status: ExecutionStatus
    completed_by: CompletionActor | None = None
    completed_at: datetime | None = None


class FamilyContributionSummary(BaseModel):
    requested: int = Field(ge=0)
    confirmed: int = Field(ge=0)
    completed: int = Field(ge=0)


class DailyReportResponse(BaseModel):
    """NFR-028에 따라 사용자와 날짜 조합당 하나만 존재하는 집계 Read Model."""

    model_config = ConfigDict(extra="forbid")

    report_id: str
    target_date: date
    finalized: bool
    completed_routines: int = Field(ge=0)
    appliance_executions: int = Field(ge=0)
    routines: list[RoutineExecutionResponse] = Field(default_factory=list)
    highest_load_area: str | None = None
    motion_cautions: list[str] = Field(default_factory=list)
    motion_summaries: list[str] = Field(default_factory=list)
    family: FamilyContributionSummary
    updated_at: datetime


class ConditionIndex(StrEnum):
    GOOD = "good"
    FAIR = "fair"
    BAD = "bad"
    HARD = "hard"


class CalendarDay(BaseModel):
    model_config = ConfigDict(extra="forbid")

    target_date: date
    condition_index: ConditionIndex
    has_report: bool
    report_finalized: bool


class CalendarDayDetailResponse(BaseModel):
    """캘린더 선택 날짜가 한 번의 요청으로 사용하는 읽기 전용 상세 모델."""

    model_config = ConfigDict(extra="forbid")

    condition: ConditionResponse
    report: DailyReportResponse


class RoutineFeedbackKind(StrEnum):
    MEAL_ACCEPT = "meal_accept"
    MEAL_REJECT = "meal_reject"
    MEAL_REPLACE = "meal_replace"


class RoutineItemUpdateInput(BaseModel):
    """FUC-W-MEAL-003/004: 챗봇이 제안한 대체 메뉴 수락·거절·재요청. `payload`는
    W-MEAL-002의 meal payload 모양(reasonTitle/reason/evidence/nutritionTags 등)을
    그대로 따르되, 이 계층에서는 내용을 검증하지 않고 그대로 전달한다."""

    model_config = ConfigDict(extra="forbid")

    feedback_kind: RoutineFeedbackKind
    payload: dict[str, Any] = Field(default_factory=dict)


class SleepEnvironmentInput(BaseModel):
    """FUC-W-SLEEP-001-1: AI 권장값 대비 override. 항목별로 선택 입력이다."""

    model_config = ConfigDict(extra="forbid")

    lighting: str | None = None
    temperature: float | None = Field(default=None, ge=0, le=40)
    humidity: float | None = Field(default=None, ge=0, le=100)
    sound: str | None = None
    air_purifier: str | None = None


class RoutineItemResponse(BaseModel):
    """갱신된 routine_item의 최소 응답. Stub 단계에서는 실제 routine_items 원본을
    모르므로 title은 항상 null이다 — 모르는 값을 지어내지 않는다."""

    model_config = ConfigDict(extra="forbid")

    routine_item_id: str
    category: RoutineCategory
    title: str | None = None
    payload: dict[str, Any]


def condition_index_from_scores(scores: dict[str, int]) -> ConditionIndex:
    """B-CAL-001의 4단계 컨디션 지수 계산. 통증·구역감·피로감 6종(mood 제외 —
    방향이 반대라 단순 평균에 섞으면 왜곡됨)의 단순 평균을 4구간으로 나눈다.

    2026-09-22 팀 결정으로 최종 확정: mood 계속 제외, 구간 경계값(2/3/4)
    현행 유지, 가중치 미도입. Stub/Supabase 양쪽이 이 함수 하나를 공유한다."""

    burden_fields = ("nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue")
    values = [scores[field] for field in burden_fields if field in scores]
    if not values:
        return ConditionIndex.FAIR
    average = sum(values) / len(values)
    if average <= 2:
        return ConditionIndex.GOOD
    if average <= 3:
        return ConditionIndex.FAIR
    if average <= 4:
        return ConditionIndex.BAD
    return ConditionIndex.HARD


class CalendarMonthResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    month: str
    days: list[CalendarDay] = Field(default_factory=list)

    @field_validator("month")
    @classmethod
    def validate_month(cls, value: str) -> str:
        try:
            datetime.strptime(value, "%Y-%m")
        except ValueError as error:
            raise ValueError("month는 YYYY-MM 형식이어야 합니다.") from error
        return value
