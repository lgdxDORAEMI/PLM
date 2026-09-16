"""이벤트 로그 저장소 (계획서 §5.8).

rule_engine.py는 프레임별 판정(FrameJudgement)만 만들고, "언제 어떤 부담
구간이 있었는지"를 리포트에서 조회 가능한 형태로 쌓는 건 이 모듈이 한다.
FrameJudgement → PostureEvent 변환 래퍼는 아직 없다 (schemas/README.md의
"다음에 이 스키마를 쓰게 될 곳" 참고) — 그게 만들어지면 여기 EventStore로
넘기기만 하면 된다.

InMemoryEventStore(데모/로컬용)와 SupabaseEventStore(2026-09-16 추가, 실제
서비스용) 둘 다 있다. 컬럼 설계는 supabase/README.md와
supabase/migrations/20260916000000_create_movement_tables.sql의
posture_events 참고. 어느 구현체든 이 Protocol만 지키면 호출부(API 라우터,
리포트 생성 모듈)는 바꿀 필요가 없다.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Protocol
from uuid import UUID

import httpx
from postgrest.exceptions import APIError

from ...schemas.movement import BurdenLabel, EventTrigger, PostureEvent, PostureType
from ..supabase_service import SupabaseService

logger = logging.getLogger(__name__)


class EventStore(Protocol):
    """자세 부담 이벤트 저장소."""

    def record(self, event: PostureEvent) -> None: ...

    def list_events(
        self,
        user_id: UUID,
        *,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> list[PostureEvent]: ...


class InMemoryEventStore:
    """데모/로컬 개발용 구현체. 프로세스가 살아있는 동안만 유지된다.

    TODO (NFR-008, 2026-09-15 결정 — 지금은 주석만): 실제 서비스에서는 이
    이벤트도 민감정보로 분류되므로, 영속 저장소로 옮길 때 암호화를 적용해야
    한다.
    """

    def __init__(self):
        self._events: list[PostureEvent] = []

    def record(self, event: PostureEvent) -> None:
        self._events.append(event)

    def list_events(
        self,
        user_id: UUID,
        *,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> list[PostureEvent]:
        return [
            e
            for e in self._events
            if e.user_id == user_id
            and (start is None or e.started_at >= start)
            and (end is None or e.ended_at <= end)
        ]


class EventStorageError(Exception):
    """DB 저장 또는 조회에 실패했다."""


class SupabaseEventStore:
    """Supabase(Postgres) 기반 EventStore 구현체 (2026-09-16 추가).

    profile_service.ProfileService와 같은 쿼리 패턴(table() 체이닝,
    APIError/httpx.HTTPError를 도메인 예외로 감싸는 _run() 헬퍼)을 따르되,
    생성자는 Client가 아니라 SupabaseService를 받는다 — 이 store는
    ProfileService처럼 요청마다 새로 만드는 게 아니라 `movement.py`가 앱 시작
    시점에 한 번만 만드는 singleton이라, `.client`(실제 연결)을 생성자에서
    바로 만들면 SUPABASE_* 환경변수가 없을 때 앱 자체가 기동 실패한다.
    SupabaseService.client는 지연 프로퍼티라, 실제 DB 요청이 오는 시점에야
    연결을 만들고 그때 실패하면 여기서 EventStorageError로 감싼다.

    TODO (NFR-008, 2026-09-15 결정 — 지금은 주석만): 이 이벤트도 민감정보로
    분류되므로, 컬럼 단위 암호화 적용이 필요할 수 있다 (지금은 미구현).
    """

    TABLE = "posture_events"

    def __init__(self, supabase: SupabaseService) -> None:
        self.supabase = supabase

    def record(self, event: PostureEvent) -> None:
        row = _event_to_row(event)
        self._run(lambda: self._client().table(self.TABLE).insert(row).execute())

    def list_events(
        self,
        user_id: UUID,
        *,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> list[PostureEvent]:
        def do_query() -> Any:
            query = self._client().table(self.TABLE).select("*").eq("user_id", str(user_id))
            if start is not None:
                query = query.gte("started_at", start.isoformat())
            if end is not None:
                query = query.lte("ended_at", end.isoformat())
            return query.order("started_at").execute()

        rows = self._run(do_query)
        return [_row_to_event(row) for row in rows]

    def _client(self) -> Any:
        try:
            return self.supabase.client
        except ValueError as error:  # SUPABASE_* 환경변수 누락
            raise EventStorageError from error

    def _run(self, request: Any) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            logger.exception("이벤트 DB 요청 실패")
            raise EventStorageError from error


def _event_to_row(event: PostureEvent) -> dict:
    return {
        "id": str(event.event_id),
        "user_id": str(event.user_id),
        "session_id": str(event.session_id),
        "posture_type": event.posture_type.value,
        "burden_label": event.burden_label.value,
        "trigger_reason": event.trigger_reason.value,
        "started_at": event.started_at.isoformat(),
        "ended_at": event.ended_at.isoformat(),
        "duration_sec": event.duration_sec,
        "rep_count_in_window": event.rep_count_in_window,
        "cumulative_bend_sec": event.cumulative_bend_sec,
        "created_at": event.created_at.isoformat(),
    }


def _row_to_event(row: dict) -> PostureEvent:
    return PostureEvent(
        event_id=UUID(row["id"]),
        user_id=UUID(row["user_id"]),
        session_id=UUID(row["session_id"]),
        posture_type=PostureType(row["posture_type"]),
        burden_label=BurdenLabel(row["burden_label"]),
        trigger_reason=EventTrigger(row["trigger_reason"]),
        started_at=_parse_dt(row["started_at"]),
        ended_at=_parse_dt(row["ended_at"]),
        duration_sec=row["duration_sec"],
        rep_count_in_window=row.get("rep_count_in_window"),
        cumulative_bend_sec=row.get("cumulative_bend_sec"),
        created_at=_parse_dt(row["created_at"]),
    )


def _parse_dt(value: str) -> datetime:
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
