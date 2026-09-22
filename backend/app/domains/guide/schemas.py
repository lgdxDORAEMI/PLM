from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict

from app.domains.care.schemas import CompletionActor, ExecutionStatus, RoutineCategory


class GuideItem(BaseModel):
    """routine_items 한 행의 화면용 최소 투영. payload 모양은 카테고리별로 다르며
    (docs/DB_ERD_스키마.md §3.2) 이 계층은 검증하지 않고 그대로 전달한다."""

    model_config = ConfigDict(extra="forbid")

    item_id: str
    item_key: str
    title: str
    description: str | None = None
    payload: dict[str, Any]
    status: ExecutionStatus
    completed_by: CompletionActor | None = None
    completed_at: datetime | None = None


class GuideResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    date: date
    category: RoutineCategory
    items: list[GuideItem]
    appliance_connection_status: str | None = None
