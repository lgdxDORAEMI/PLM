import tempfile
import unittest
import uuid
from pathlib import Path

import numpy as np

from backend.app.schemas.movement import BurdenLabel, EventTrigger, PostureType
from backend.app.services.movement.calibration import CalibrationProfile, LocalFileCalibrationStore
from backend.app.services.movement.events import InMemoryEventStore
from backend.app.services.movement.features import compute_features, three_point_angle
from backend.app.services.movement.pose_extractor import PoseResult
from backend.app.services.movement.rule_engine import RuleEngine
from backend.app.services.movement.session_manager import SessionManager
from .camera import CameraConfig


class MotionTest(unittest.TestCase):
    def test_known_joint_angle(self) -> None:
        self.assertAlmostEqual(
            three_point_angle(np.array([0, 1]), np.array([0, 0]), np.array([1, 0])),
            90,
        )

    def test_low_visibility_rejects_frame(self) -> None:
        pose = PoseResult(np.zeros((33, 2)), np.zeros(33), np.zeros((33, 3)))
        result = compute_features(pose)
        self.assertFalse(result.valid)
        self.assertIn("left_ankle", result.low_visibility)

    def test_calibration_deviations(self) -> None:
        profile = CalibrationProfile(10, 175, 45, 0)
        self.assertEqual(profile.trunk_deviation(35), 25)
        self.assertEqual(profile.knee_deviation(125), -50)

    def test_bending_from_zero_timestamp_counts_once(self) -> None:
        engine = RuleEngine()
        engine.update(0, True, trunk_dev=30, knee_dev=0)
        result = engine.update(1, True, trunk_dev=0, knee_dev=0)
        self.assertEqual(result.bend_reps_in_window, 1)

    def test_tracking_loss_becomes_unknown(self) -> None:
        engine = RuleEngine()
        engine.update(0, True, trunk_dev=0, knee_dev=0)
        result = engine.update(engine.grace_period_sec + 1, False)
        self.assertEqual(result.posture, "Unknown")

    def test_sessions_do_not_share_repetition_state(self) -> None:
        first, second = RuleEngine(), RuleEngine()
        first.update(0, True, trunk_dev=30, knee_dev=0)
        first.update(1, True, trunk_dev=0, knee_dev=0)
        result = second.update(1, True, trunk_dev=0, knee_dev=0)
        self.assertEqual(result.bend_reps_in_window, 0)

    def test_camera_config_loads_from_new_location(self) -> None:
        config = CameraConfig.load()
        self.assertEqual((config.width, config.height), (1280, 720))
        self.assertEqual(config.index, 0)


class SessionManagerTest(unittest.TestCase):
    def _make_manager(self) -> tuple[SessionManager, InMemoryEventStore]:
        with tempfile.TemporaryDirectory() as tmp:
            store = LocalFileCalibrationStore(base_dir=Path(tmp))
            events = InMemoryEventStore()
            return SessionManager(calibration_store=store, event_store=events), events

    def test_start_session_loads_existing_calibration(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cal_store = LocalFileCalibrationStore(base_dir=Path(tmp))
            user_id = uuid.uuid4()
            profile = CalibrationProfile(10, 175, 45, 0)
            cal_store.save(user_id, profile)

            manager = SessionManager(calibration_store=cal_store, event_store=InMemoryEventStore())
            session_id = manager.start_session(user_id)

            state = manager.update_judgement(session_id, t=0, valid=False)
            self.assertEqual(state.posture, PostureType.UNKNOWN)

    def test_prolonged_bend_closes_into_event_and_tally(self) -> None:
        manager, events = self._make_manager()
        user_id = uuid.uuid4()
        session_id = manager.start_session(user_id)
        manager.set_calibration(session_id, CalibrationProfile(10, 175, 45, 0))

        manager.update_judgement(session_id, t=0, valid=True, trunk_dev=30, knee_dev=0)
        state = manager.update_judgement(session_id, t=9, valid=True, trunk_dev=30, knee_dev=0)
        self.assertEqual(state.burden_label, BurdenLabel.PROLONGED_LOAD)
        self.assertEqual(len(events.list_events(user_id)), 0)

        manager.update_judgement(session_id, t=9.5, valid=True, trunk_dev=0, knee_dev=0)
        recorded = events.list_events(user_id)
        self.assertEqual(len(recorded), 1)
        self.assertEqual(recorded[0].posture_type, PostureType.BENDING)
        self.assertEqual(recorded[0].burden_label, BurdenLabel.PROLONGED_LOAD)
        self.assertAlmostEqual(recorded[0].duration_sec, 9.5, places=3)

        live = manager.get_live_state(session_id)
        self.assertEqual(len(live.tallies), 1)
        self.assertEqual(live.tallies[0].posture_type, PostureType.BENDING)
        self.assertEqual(live.tallies[0].event_count, 1)

    def test_sit_to_stand_records_instant_high_load_event(self) -> None:
        manager, events = self._make_manager()
        user_id = uuid.uuid4()
        session_id = manager.start_session(user_id)
        manager.set_calibration(session_id, CalibrationProfile(10, 175, 45, 0))

        manager.update_judgement(session_id, t=0, valid=True, trunk_dev=0, knee_dev=-50)
        manager.update_judgement(session_id, t=1.5, valid=True, trunk_dev=0, knee_dev=-50)
        state = manager.update_judgement(session_id, t=2.0, valid=True, trunk_dev=0, knee_dev=0)

        self.assertEqual(state.burden_label, BurdenLabel.HIGH_LOAD_ACTION)
        recorded = events.list_events(user_id)
        self.assertEqual(len(recorded), 1)
        self.assertEqual(recorded[0].trigger_reason, EventTrigger.SIT_TO_STAND)
        self.assertEqual(recorded[0].duration_sec, 0.0)

    def test_end_session_closes_open_event(self) -> None:
        manager, events = self._make_manager()
        user_id = uuid.uuid4()
        session_id = manager.start_session(user_id)
        manager.set_calibration(session_id, CalibrationProfile(10, 175, 45, 0))

        manager.update_judgement(session_id, t=0, valid=True, trunk_dev=30, knee_dev=0)
        manager.update_judgement(session_id, t=9, valid=True, trunk_dev=30, knee_dev=0)
        manager.end_session(session_id)

        recorded = events.list_events(user_id)
        self.assertEqual(len(recorded), 1)
        self.assertEqual(recorded[0].burden_label, BurdenLabel.PROLONGED_LOAD)


if __name__ == "__main__":
    unittest.main()
