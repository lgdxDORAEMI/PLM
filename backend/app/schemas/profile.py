from datetime import date, timedelta
from decimal import Decimal
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.utils import dates

# 범위는 migration의 CHECK 제약과 동일하게 유지한다.
POST_DUE_GRACE_DAYS = 14

# 출산예정일 입력 상한. 임신 기간(280일)보다 넉넉하게 1년까지 허용한다.
# dates.FULL_TERM_DAYS와 분리해 둔다 — 임신 주수 계산은 그대로 280일 기준이다.
MAX_DUE_AHEAD_DAYS = 365
MIN_HEIGHT_CM, MAX_HEIGHT_CM = 100, 250
MIN_WEIGHT_KG, MAX_WEIGHT_KG = 30, 200

# 소수 첫째 자리까지만 허용한다(165.55는 거부).
HeightCm = Annotated[
    Decimal,
    Field(ge=MIN_HEIGHT_CM, le=MAX_HEIGHT_CM, max_digits=4, decimal_places=1),
]
WeightKg = Annotated[
    Decimal,
    Field(ge=MIN_WEIGHT_KG, le=MAX_WEIGHT_KG, max_digits=4, decimal_places=1),
]


class DueDateInput(BaseModel):
    """프로필 설정 1/6. 출산예정일이 기본 입력이고 마지막 생리 시작일은 선택이다.

    출산예정일은 보통 병원에서 진단받아 오므로 그 값을 그대로 쓴다.
    마지막 생리 시작일만 보내면 `+280일`로 출산예정일을 계산해 준다.
    둘 다 보내면 계산값으로 덮어쓰지 않고 병원 진단값(`due_date`)을 그대로 저장한다 —
    실제 출산예정일은 초음파 측정으로 조정되므로 `마지막 생리 시작일 + 280일`과
    며칠 어긋나는 것이 정상이다. 예전에는 두 값이 다르면 거부했지만 그 규칙은 없앴다.
    """

    model_config = ConfigDict(extra="forbid")

    due_date: date | None = None
    last_period_start: date | None = None

    @model_validator(mode="after")
    def resolve_due_date(self) -> Self:
        today = dates.today_kst()

        if self.last_period_start is not None and self.last_period_start > today:
            raise ValueError("마지막 생리 시작일은 미래일 수 없습니다.")

        # 출산예정일을 안 보낸 경우에만 마지막 생리 시작일로 계산한다.
        if self.due_date is None and self.last_period_start is not None:
            self.due_date = self.last_period_start + timedelta(days=dates.FULL_TERM_DAYS)
        if self.due_date is None:
            raise ValueError("출산예정일 또는 마지막 생리 시작일 중 하나는 필요합니다.")

        earliest = today - timedelta(days=POST_DUE_GRACE_DAYS)
        latest = today + timedelta(days=MAX_DUE_AHEAD_DAYS)
        if not earliest <= self.due_date <= latest:
            raise ValueError(
                f"출산예정일은 오늘 기준 {POST_DUE_GRACE_DAYS}일 전부터 "
                f"{MAX_DUE_AHEAD_DAYS}일 후까지만 가능합니다."
            )
        return self


class BodyInput(BaseModel):
    """프로필 설정 2/6. 생년월일(→나이)·임신 전 신장·체중을 함께 저장한다."""

    model_config = ConfigDict(extra="forbid")

    birth_date: date
    height_cm: HeightCm
    pre_pregnancy_weight_kg: WeightKg

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, value: date) -> date:
        if value >= dates.today_kst():
            raise ValueError("생년월일은 오늘보다 이전이어야 합니다.")
        return value


class PregnancyHistoryInput(BaseModel):
    """프로필 설정 3/6. 초산/경산 여부."""

    model_config = ConfigDict(extra="forbid")

    is_first_pregnancy: bool


class PregnancyCountInput(BaseModel):
    """프로필 설정 4/6. 단태/쌍태 여부."""

    model_config = ConfigDict(extra="forbid")

    is_multiple_pregnancy: bool


MAX_ALLERGY_ITEMS = 30
MAX_MEDICAL_CONDITION_ITEMS = 30
MAX_MEDICAL_NOTE_LENGTH = 1000


class AllergiesInput(BaseModel):
    """프로필 설정 5/6. 다중 선택. "없어요"는 빈 배열로 저장한다."""

    model_config = ConfigDict(extra="forbid")

    allergies: list[str] = Field(default_factory=list, max_length=MAX_ALLERGY_ITEMS)


class MedicalNotesInput(BaseModel):
    """프로필 설정 6/6. 주의 진단 다중 선택 + 자유 텍스트."""

    model_config = ConfigDict(extra="forbid")

    medical_conditions: list[str] = Field(
        default_factory=list, max_length=MAX_MEDICAL_CONDITION_ITEMS
    )
    medical_note: str = Field(default="", max_length=MAX_MEDICAL_NOTE_LENGTH)


class ProfileResponse(BaseModel):
    due_date: date | None
    last_period_start: date | None
    birth_date: date | None
    age: int | None
    height_cm: float | None
    pre_pregnancy_weight_kg: float | None
    is_first_pregnancy: bool | None
    is_multiple_pregnancy: bool | None
    allergies: list[str]
    medical_conditions: list[str]
    medical_note: str
    pregnancy_weeks: int | None
    pregnancy_days: int | None

    # 연속으로 완료한 프로필 설정 단계 수. 진행바·이어하기에 쓴다.
    # allergies/medical_conditions는 DB 컬럼이 not null default '{}'라 "아직 입력
    # 안 함"과 "빈 배열을 선택함"을 컬럼값만으로 구분할 수 없다 — 그래서 이 두 단계는
    # STEP_COLUMNS(완료 단계 계산)에 포함하지 않는다. 즉 completed_step은 최대 4까지만
    # 정확하고, 5~6단계 저장 여부는 이 필드로 알 수 없다(TBD: nullable 컬럼 또는 별도
    # 완료 플래그로 스키마를 바꾸기 전까지는 프런트가 allergies/medical_note 자체의
    # 존재 여부로 판단해야 한다).
    completed_step: int
