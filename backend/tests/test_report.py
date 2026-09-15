"""report.py(§5.9) 집계 로직 단위 테스트.

EventStore/SessionManager를 거치지 않고 PostureEvent를 직접 만들어 넣는다 —
judgement가 이벤트를 얼마나 정확히 만드는지는 SessionManager 쪽 테스트에서 이미
검증했으므로, 여기서는 "이벤트가 주어졌을 때 집계·최다 부담 부위·문구 생성이
맞는가"만 확인한다.
"""

import unittest
import uuid
from datetime import datetime, timedelta, timezone

from app.schemas.movement import BodyPart, BurdenLabel, EventTrigger, PostureEvent, PostureType
from app.services.movement.events import InMemoryEventStore
from app.services.movement.report import generate_daily_report

_USER_ID = uuid.uuid4()
_TODAY = datetime.now(timezone.utc).date()
_BASE = datetime.combine(_TODAY, datetime.min.time(), tzinfo=timezone.utc)


def _event(hour: int, posture, label, trigger, duration_sec: float) -> PostureEvent:
    t = _BASE.replace(hour=hour)
    return PostureEvent(
        event_id=uuid.uuid4(),
        user_id=_USER_ID,
        session_id=uuid.uuid4(),
        posture_type=posture,
        burden_label=label,
        started_at=t,
        ended_at=t,
        duration_sec=duration_sec,
        trigger_reason=trigger,
        created_at=t,
    )


class ReportTest(unittest.TestCase):
    def test_empty_store_returns_empty_report(self) -> None:
        report = generate_daily_report(InMemoryEventStore(), _USER_ID, _TODAY)
        self.assertEqual(report.aggregates, [])
        self.assertIsNone(report.top_burdened_body_part)
        self.assertEqual(report.narratives, [])

    def test_groups_by_posture_and_label(self) -> None:
        store = InMemoryEventStore()
        # 같은 (posture_type, burden_label) 조합 2건은 하나로 합쳐져야 한다.
        store.record(_event(9, PostureType.BENDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 8.0))
        store.record(_event(10, PostureType.BENDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 12.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(len(report.aggregates), 1)
        agg = report.aggregates[0]
        self.assertEqual(agg.posture_type, PostureType.BENDING)
        self.assertEqual(agg.body_part, BodyPart.TRUNK)
        self.assertEqual(agg.count, 2)
        self.assertEqual(agg.total_duration_sec, 20.0)
        self.assertEqual(agg.max_duration_sec, 12.0)

    def test_normal_label_produces_no_narrative(self) -> None:
        store = InMemoryEventStore()
        store.record(_event(9, PostureType.STANDING, BurdenLabel.NORMAL, EventTrigger.STATE_DURATION, 2.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(len(report.aggregates), 1)
        self.assertEqual(report.narratives, [])

    def test_sit_to_stand_frequency_outranks_single_long_bend_for_top_burdened(self) -> None:
        """total_duration_sec 합산만으로 고르면 Sit-to-Stand(항상 duration=0)가
        아무리 자주 일어나도 절대 1위가 될 수 없다는 게 이전에 실제로 확인된
        버그였다. count * 심각도로 고치고 나서는 12회 반복이 1회짜리 9.5초
        허리 부담보다 위여야 한다."""
        store = InMemoryEventStore()
        for hour in range(8, 20):
            store.record(
                _event(hour, PostureType.SITTING, BurdenLabel.HIGH_LOAD_ACTION, EventTrigger.SIT_TO_STAND, 0.0)
            )
        store.record(_event(21, PostureType.BENDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 9.5))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(report.top_burdened_body_part, BodyPart.KNEE)
        sit_to_stand_narratives = [n for n in report.narratives if "일어나는 동작" in n]
        self.assertEqual(len(sit_to_stand_narratives), 1)
        self.assertIn("12회", sit_to_stand_narratives[0])

    def test_only_events_within_the_day_are_included(self) -> None:
        store = InMemoryEventStore()
        yesterday = _BASE - timedelta(days=1)
        store.record(
            PostureEvent(
                event_id=uuid.uuid4(),
                user_id=_USER_ID,
                session_id=uuid.uuid4(),
                posture_type=PostureType.BENDING,
                burden_label=BurdenLabel.PROLONGED_LOAD,
                started_at=yesterday,
                ended_at=yesterday,
                duration_sec=9.0,
                trigger_reason=EventTrigger.STATE_DURATION,
                created_at=yesterday,
            )
        )

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(report.aggregates, [])


if __name__ == "__main__":
    unittest.main()
