from datetime import date, timedelta
from decimal import Decimal
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.utils import dates

# 범위는 migration의 CHECK 제약과 동일하게 유지한다.
POST_DUE_GRACE_DAYS = 14
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
    """프로필 설정 1/6. 출산예정일 또는 마지막 생리 시작일 중 하나 이상."""

    model_config = ConfigDict(extra="forbid")

    due_date: date | None = None
    last_period_start: date | None = None

    @model_validator(mode="after")
    def resolve_due_date(self) -> Self:
        if self.last_period_start is not None:
            computed = self.last_period_start + timedelta(days=dates.FULL_TERM_DAYS)
            if self.due_date is not None and self.due_date != computed:
                raise ValueError(
                    "출산예정일이 마지막 생리 시작일 + 280일과 다릅니다."
                )
            self.due_date = computed
        if self.due_date is None:
            raise ValueError("출산예정일 또는 마지막 생리 시작일 중 하나는 필요합니다.")

        today = dates.today_kst()
        earliest = today - timedelta(days=POST_DUE_GRACE_DAYS)
        latest = today + timedelta(days=dates.FULL_TERM_DAYS)
        if not earliest <= self.due_date <= latest:
            raise ValueError(
                f"출산예정일은 오늘 기준 {POST_DUE_GRACE_DAYS}일 전부터 "
                f"{dates.FULL_TERM_DAYS}일 후까지만 가능합니다."
            )
        return self


class BodyInput(BaseModel):
    """프로필 설정 2/6. 임신 전 신장·체중은 함께 저장한다."""

    model_config = ConfigDict(extra="forbid")

    height_cm: HeightCm
    pre_pregnancy_weight_kg: WeightKg


class ProfileResponse(BaseModel):
    due_date: date | None
    last_period_start: date | None
    height_cm: float | None
    pre_pregnancy_weight_kg: float | None
    pregnancy_weeks: int | None
    pregnancy_days: int | None

    # 연속으로 완료한 프로필 설정 단계 수. 진행바·이어하기에 쓴다.
    completed_step: int
