import logging
from collections.abc import Callable
from datetime import date, datetime, timezone
from typing import Any

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.schemas.profile import BodyInput, DueDateInput, ProfileResponse
from app.utils import dates

logger = logging.getLogger(__name__)

TABLE = "pregnancy_profiles"
PROFILE_COLUMNS = ("due_date", "last_period_start", "height_cm", "pre_pregnancy_weight_kg")

# 단계별로 채워져야 하는 컬럼. 3~6단계 화면설계서가 나오면 순서대로 추가한다.
STEP_COLUMNS: tuple[tuple[str, ...], ...] = (
    ("due_date",),
    ("height_cm", "pre_pregnancy_weight_kg"),
)

Row = dict[str, Any]


class ProfileStepOrderError(Exception):
    """앞 단계를 저장하지 않고 다음 단계를 저장하려 했다."""


class ProfileStorageError(Exception):
    """DB 저장 또는 조회에 실패했다."""


def completed_step(row: Row) -> int:
    count = 0
    for columns in STEP_COLUMNS:
        if any(row.get(column) is None for column in columns):
            break
        count += 1
    return count


class ProfileService:
    def __init__(self, client: Client) -> None:
        self.client = client

    def get(self, user_id: str) -> ProfileResponse | None:
        rows = self._run(
            lambda: self.client.table(TABLE)
            .select(*PROFILE_COLUMNS)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return _to_response(rows[0]) if rows else None

    def save_due_date(self, user_id: str, data: DueDateInput) -> ProfileResponse:
        assert data.due_date is not None  # DueDateInput 검증에서 보장된다.
        row = {
            "user_id": user_id,
            "due_date": data.due_date.isoformat(),
            # 출산예정일을 직접 고르면 이전 생리 시작일은 비운다.
            "last_period_start": (
                data.last_period_start.isoformat() if data.last_period_start else None
            ),
            "updated_at": _now(),
        }
        # default_to_null=False: 요청에 없는 컬럼(2단계 이후 값)을 null로 덮어쓰지 않는다.
        rows = self._run(
            lambda: self.client.table(TABLE)
            .upsert(row, on_conflict="user_id", default_to_null=False)
            .execute()
        )
        return _to_response(rows[0])

    def save_body(self, user_id: str, data: BodyInput) -> ProfileResponse:
        values = {
            "height_cm": float(data.height_cm),
            "pre_pregnancy_weight_kg": float(data.pre_pregnancy_weight_kg),
            "updated_at": _now(),
        }
        rows = self._run(
            lambda: self.client.table(TABLE)
            .update(values)
            .eq("user_id", user_id)
            .execute()
        )
        # 행은 1단계 저장 때만 생기므로, 수정된 행이 없으면 1단계가 없는 것이다.
        if not rows:
            raise ProfileStepOrderError
        return _to_response(rows[0])

    def _run(self, request: Callable[[], Any]) -> list[Row]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            logger.exception("프로필 DB 요청 실패")
            raise ProfileStorageError from error


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _to_response(row: Row) -> ProfileResponse:
    weeks = days = None
    if row.get("due_date") is not None:
        due_date = date.fromisoformat(str(row["due_date"]))
        weeks, days = dates.pregnancy_age(due_date, dates.today_kst())
    return ProfileResponse(
        **{column: row.get(column) for column in PROFILE_COLUMNS},
        pregnancy_weeks=weeks,
        pregnancy_days=days,
        completed_step=completed_step(row),
    )
