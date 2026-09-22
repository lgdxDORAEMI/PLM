"""report.py(§5.9) 집계 로직 단위 테스트.

EventStore/SessionManager를 거치지 않고 PostureEvent를 직접 만들어 넣는다 —
judgement가 이벤트를 얼마나 정확히 만드는지는 SessionManager 쪽 테스트에서 이미
검증했으므로, 여기서는 "이벤트가 주어졌을 때 집계·최다 부담 부위·문구 생성이
맞는가"만 확인한다.
"""

import unittest
import uuid
from datetime import timedelta

from app.schemas.movement import BodyPart, BurdenLabel, EventTrigger, PostureEvent, PostureType
from app.services.movement.events import InMemoryEventStore
from app.services.movement.report import generate_daily_report
from app.utils import dates

_USER_ID = uuid.uuid4()
_TODAY = dates.today_kst()
_BASE, _ = dates.day_bounds_kst(_TODAY)


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
        self.assertEqual(report.bending_burden_event_count, 0)

    def test_bending_burden_event_count_combines_bending_and_high_load_action(self) -> None:
        """2026-09-16 팀 결정: Bending의 Repeated Load/Prolonged Load와
        High-load Action(Sit-to-Stand)의 포착 횟수를 하나로 합산해 노출한다.
        High-load Action은 posture_type=Standing으로 기록되지만(무릎 동작이라
        Bending으로 태깅하지 않음) 그래도 이 카운트에는 포함되어야 하고,
        Standing의 Prolonged Load처럼 Bending도 High-load Action도 아닌
        이벤트는 포함되면 안 된다."""
        store = InMemoryEventStore()
        store.record(_event(9, PostureType.BENDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 8.0))
        store.record(_event(10, PostureType.BENDING, BurdenLabel.REPEATED_LOAD, EventTrigger.REPEATED_COUNT, 3.0))
        store.record(
            _event(11, PostureType.STANDING, BurdenLabel.HIGH_LOAD_ACTION, EventTrigger.SIT_TO_STAND, 0.0)
        )
        # 아래 둘은 카운트에 포함되면 안 됨: Standing-Prolonged Load, Sitting-Normal
        store.record(_event(12, PostureType.STANDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 20.0))
        store.record(_event(13, PostureType.SITTING, BurdenLabel.NORMAL, EventTrigger.STATE_DURATION, 1.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(report.bending_burden_event_count, 3)

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

    def test_narratives_sorted_by_group_count_regardless_of_occurrence_order(self) -> None:
        """narratives[0]이 화면에 그대로 노출되므로(2026-09-23 결정), 먼저
        발생한 그룹이 아니라 더 많이 발생한 그룹의 문장이 앞에 와야 한다."""
        store = InMemoryEventStore()
        # 먼저 발생했지만 2회뿐인 그룹.
        store.record(_event(8, PostureType.STANDING, BurdenLabel.HIGH_LOAD_ACTION, EventTrigger.SIT_TO_STAND, 0.0))
        store.record(_event(9, PostureType.STANDING, BurdenLabel.HIGH_LOAD_ACTION, EventTrigger.SIT_TO_STAND, 0.0))
        # 나중에 발생했지만 3회인 그룹.
        store.record(_event(14, PostureType.BENDING, BurdenLabel.REPEATED_LOAD, EventTrigger.REPEATED_COUNT, 1.0))
        store.record(_event(15, PostureType.BENDING, BurdenLabel.REPEATED_LOAD, EventTrigger.REPEATED_COUNT, 1.0))
        store.record(_event(16, PostureType.BENDING, BurdenLabel.REPEATED_LOAD, EventTrigger.REPEATED_COUNT, 1.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(len(report.narratives), 2)
        self.assertIn("반복적으로 관찰됐습니다", report.narratives[0])
        self.assertIn("낮은 의자에서 일어나는", report.narratives[1])

    def test_narratives_tie_breaks_by_earlier_occurrence(self) -> None:
        """횟수가 같으면 먼저 발생한 그룹의 문장이 앞에 온다."""
        store = InMemoryEventStore()
        store.record(_event(8, PostureType.STANDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 20.0))
        store.record(_event(14, PostureType.BENDING, BurdenLabel.REPEATED_LOAD, EventTrigger.REPEATED_COUNT, 1.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(len(report.narratives), 2)
        self.assertIn("서 있는", report.narratives[0])
        self.assertIn("허리를 숙이는", report.narratives[1])

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

    def test_cumulative_forward_bend_is_summed_separately_not_mixed_into_aggregates(self) -> None:
        """2026-09-15 결정: CUMULATIVE_RESEARCH_THRESHOLD 이벤트는 자세유형×라벨
        집계(aggregates)에 안 섞이고, 하루 총합만 별도 필드/문구로 나와야 한다."""
        store = InMemoryEventStore()
        # SessionManager.end_session()이 세션 두 개에서 남겼다고 가정 (사용자가
        # 재접속했다면 세션이 여러 개일 수 있음) — 둘 다 그날 총합에 더해져야 한다.
        store.record(_event(9, PostureType.BENDING, BurdenLabel.NORMAL, EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD, 12.0))
        store.record(
            _event(15, PostureType.BENDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD, 8.0)
        )

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(report.aggregates, [])  # 일반 집계에는 전혀 안 나타남
        self.assertIsNone(report.top_burdened_body_part)
        self.assertEqual(report.cumulative_forward_bend_sec, 20.0)
        self.assertEqual(len(report.narratives), 1)
        self.assertIn("누적 시간", report.narratives[0])

    def test_no_cumulative_narrative_when_zero(self) -> None:
        store = InMemoryEventStore()
        store.record(_event(9, PostureType.STANDING, BurdenLabel.PROLONGED_LOAD, EventTrigger.STATE_DURATION, 20.0))

        report = generate_daily_report(store, _USER_ID, _TODAY)

        self.assertEqual(report.cumulative_forward_bend_sec, 0.0)
        self.assertFalse(any("누적 시간" in n for n in report.narratives))


if __name__ == "__main__":
    unittest.main()
