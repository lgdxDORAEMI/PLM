"""이벤트 로그 저장소 (계획서 §5.8).

rule_engine.py는 프레임별 판정(FrameJudgement)만 만들고, "언제 어떤 부담
구간이 있었는지"를 리포트에서 조회 가능한 형태로 쌓는 건 이 모듈이 한다.
FrameJudgement → PostureEvent 변환 래퍼는 아직 없다 (schemas/README.md의
"다음에 이 스키마를 쓰게 될 곳" 참고) — 그게 만들어지면 여기 EventStore로
넘기기만 하면 된다.

지금은 InMemoryEventStore만 있다. 실제 서비스에서는 Supabase 구현체로
교체한다 (컬럼 설계는 supabase/README.md의 posture_events 참고). 어느
구현체든 이 Protocol만 지키면 호출부(향후 API 라우터, 리포트 생성 모듈)는
바꿀 필요가 없다.
"""

from __future__ import annotations

from datetime import datetime
from typing import Protocol
from uuid import UUID

from ...schemas.movement import PostureEvent


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
