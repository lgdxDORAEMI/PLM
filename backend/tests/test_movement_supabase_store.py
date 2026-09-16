"""SupabaseEventStore/SupabaseCalibrationStore(2026-09-16 추가) 단위 테스트.

test_profile.py의 FakeSupabaseClient/FakeQuery 패턴을 그대로 따른다 — 실제
Supabase에 붙지 않고 table().insert/select/eq/gte/lte/order/limit().execute()
체이닝만 흉내 낸다.
"""

import unittest
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from postgrest.exceptions import APIError

from app.schemas.movement import BurdenLabel, EventTrigger, PostureEvent, PostureType
from app.services.movement.calibration import (
    CalibrationProfile,
    CalibrationStorageError,
    SupabaseCalibrationStore,
)
from app.services.movement.events import EventStorageError, SupabaseEventStore

_USER_ID = uuid.uuid4()


class FakeQuery:
    def __init__(self, rows_ref: list[dict], subset: list[dict]) -> None:
        self.rows_ref = rows_ref
        self.subset = subset
        self._raise = False

    def eq(self, column: str, value) -> "FakeQuery":
        self.subset = [r for r in self.subset if str(r.get(column)) == str(value)]
        return self

    def gte(self, column: str, value) -> "FakeQuery":
        self.subset = [r for r in self.subset if r.get(column) >= value]
        return self

    def lte(self, column: str, value) -> "FakeQuery":
        self.subset = [r for r in self.subset if r.get(column) <= value]
        return self

    def order(self, column: str, desc: bool = False) -> "FakeQuery":
        self.subset = sorted(self.subset, key=lambda r: r.get(column), reverse=desc)
        return self

    def limit(self, size: int) -> "FakeQuery":
        self.subset = self.subset[:size]
        return self

    def execute(self) -> SimpleNamespace:
        if self._raise:
            raise APIError({"message": "boom"})
        return SimpleNamespace(data=self.subset)


class FakeTable:
    def __init__(self, rows_ref: list[dict], fail: bool) -> None:
        self.rows_ref = rows_ref
        self.fail = fail

    def insert(self, row: dict) -> FakeQuery:
        query = FakeQuery(self.rows_ref, [row])
        query._raise = self.fail
        if not self.fail:
            self.rows_ref.append(row)
        return query

    def select(self, *columns: str) -> FakeQuery:
        query = FakeQuery(self.rows_ref, list(self.rows_ref))
        query._raise = self.fail
        return query


class FakeSupabaseClient:
    """table() 호출마다 새 FakeTable을 만들지만, 실패 플래그는 테이블 이름별로
    클라이언트에 보관해서 store 내부의 self.client.table(...) 호출에도 이어진다."""

    def __init__(self) -> None:
        self._tables: dict[str, list[dict]] = {}
        self._fail: dict[str, bool] = {}

    def table(self, name: str) -> FakeTable:
        return FakeTable(self._tables.setdefault(name, []), fail=self._fail.get(name, False))

    def fail_next(self, name: str) -> None:
        self._fail[name] = True


class FakeSupabaseService:
    """SupabaseService 대역. Store들은 Client가 아니라 이 객체를 주입받아서
    (실제 SupabaseService처럼) .client 접근을 늦게 하고, 환경변수 누락 시
    ValueError를 던지는 것까지 흉내 낼 수 있다."""

    def __init__(self, client: FakeSupabaseClient | None = None, missing_config: bool = False) -> None:
        self._client = client or FakeSupabaseClient()
        self.missing_config = missing_config

    @property
    def client(self) -> FakeSupabaseClient:
        if self.missing_config:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        return self._client


def _event(hour: int, **overrides) -> PostureEvent:
    t = datetime(2026, 9, 16, hour, tzinfo=timezone.utc)
    defaults = dict(
        event_id=uuid.uuid4(),
        user_id=_USER_ID,
        session_id=uuid.uuid4(),
        posture_type=PostureType.BENDING,
        burden_label=BurdenLabel.PROLONGED_LOAD,
        started_at=t,
        ended_at=t + timedelta(seconds=9),
        duration_sec=9.0,
        trigger_reason=EventTrigger.STATE_DURATION,
        rep_count_in_window=None,
        cumulative_bend_sec=None,
        created_at=t,
    )
    defaults.update(overrides)
    return PostureEvent(**defaults)


class SupabaseEventStoreTest(unittest.TestCase):
    def test_record_then_list_events_round_trips(self) -> None:
        store = SupabaseEventStore(FakeSupabaseService())
        event = _event(9)

        store.record(event)
        result = store.list_events(_USER_ID)

        self.assertEqual(result, [event])

    def test_list_events_filters_by_user_and_range(self) -> None:
        store = SupabaseEventStore(FakeSupabaseService())
        other_user = uuid.uuid4()
        in_range = _event(10)
        out_of_range = _event(20)
        other_users_event = _event(11, user_id=other_user)
        for event in (in_range, out_of_range, other_users_event):
            store.record(event)

        result = store.list_events(
            _USER_ID,
            start=datetime(2026, 9, 16, 9, tzinfo=timezone.utc),
            end=datetime(2026, 9, 16, 15, tzinfo=timezone.utc),
        )

        self.assertEqual(result, [in_range])

    def test_api_error_is_wrapped(self) -> None:
        client = FakeSupabaseClient()
        client.fail_next("posture_events")
        store = SupabaseEventStore(FakeSupabaseService(client))

        with self.assertRaises(EventStorageError):
            store.record(_event(9))

    def test_missing_config_is_wrapped(self) -> None:
        store = SupabaseEventStore(FakeSupabaseService(missing_config=True))

        with self.assertRaises(EventStorageError):
            store.record(_event(9))


class SupabaseCalibrationStoreTest(unittest.TestCase):
    def test_load_without_save_returns_none(self) -> None:
        store = SupabaseCalibrationStore(FakeSupabaseService())
        self.assertIsNone(store.load(_USER_ID))

    def test_save_then_load_round_trips(self) -> None:
        store = SupabaseCalibrationStore(FakeSupabaseService())
        profile = CalibrationProfile(
            baseline_trunk_flexion=12.5,
            baseline_knee_angle=170.0,
            frame_count=45,
            captured_at=1_800_000_000.0,
        )

        store.save(_USER_ID, profile)
        loaded = store.load(_USER_ID)

        self.assertIsNotNone(loaded)
        self.assertAlmostEqual(loaded.baseline_trunk_flexion, profile.baseline_trunk_flexion)
        self.assertAlmostEqual(loaded.baseline_knee_angle, profile.baseline_knee_angle)
        self.assertEqual(loaded.frame_count, profile.frame_count)
        self.assertAlmostEqual(loaded.captured_at, profile.captured_at, places=3)

    def test_load_returns_most_recent_recalibration(self) -> None:
        store = SupabaseCalibrationStore(FakeSupabaseService())
        older = CalibrationProfile(10.0, 170.0, 45, captured_at=1_000.0)
        newer = CalibrationProfile(20.0, 160.0, 45, captured_at=2_000.0)

        store.save(_USER_ID, older)
        store.save(_USER_ID, newer)
        loaded = store.load(_USER_ID)

        self.assertAlmostEqual(loaded.baseline_trunk_flexion, newer.baseline_trunk_flexion)

    def test_api_error_is_wrapped(self) -> None:
        client = FakeSupabaseClient()
        client.fail_next("posture_calibration_profiles")
        store = SupabaseCalibrationStore(FakeSupabaseService(client))

        with self.assertRaises(CalibrationStorageError):
            store.save(_USER_ID, CalibrationProfile(1.0, 2.0, 3, 4.0))

    def test_missing_config_is_wrapped(self) -> None:
        store = SupabaseCalibrationStore(FakeSupabaseService(missing_config=True))

        with self.assertRaises(CalibrationStorageError):
            store.save(_USER_ID, CalibrationProfile(1.0, 2.0, 3, 4.0))


if __name__ == "__main__":
    unittest.main()
