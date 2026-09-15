import tempfile
import unittest
import uuid
from pathlib import Path

import numpy as np

from backend.app.schemas.movement import BurdenLabel, EventTrigger, PostureType
from backend.app.services.movement.calibration import CalibrationProfile, LocalFileCalibrationStore
from backend.app.services.movement.events import InMemoryEventStore
from backend.app.services.movement.features import compute_features, three_point_angle
from backend.app.services.movement.pose_extractor import (
    LEFT_ANKLE,
    LEFT_HIP,
    LEFT_KNEE,
    LEFT_SHOULDER,
    RIGHT_ANKLE,
    RIGHT_HIP,
    RIGHT_KNEE,
    RIGHT_SHOULDER,
    PoseResult,
)
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

    def _standing_pose(self, right_visibility: float = 1.0, right_knee_world=None) -> PoseResult:
        """양 다리를 곧게 펴고 선 자세. right_visibility로 오른쪽(먼 쪽) 관절
        가시성을, right_knee_world로 오른쪽 무릎 world 좌표를 바꿔서 "옆모습
        때문에 반대쪽이 가려지고 잘못 추정된" 상황을 흉내낸다."""
        world = np.zeros((33, 3))
        world[LEFT_HIP] = (-0.1, 0, 0)
        world[RIGHT_HIP] = (0.1, 0, 0)
        world[LEFT_SHOULDER] = (-0.1, -0.5, 0)
        world[RIGHT_SHOULDER] = (0.1, -0.5, 0)
        world[LEFT_KNEE] = (-0.1, 0.5, 0)
        world[RIGHT_KNEE] = right_knee_world if right_knee_world is not None else (0.1, 0.5, 0)
        world[LEFT_ANKLE] = (-0.1, 1.0, 0)
        world[RIGHT_ANKLE] = (0.1, 1.0, 0)

        visibility = np.ones(33)
        for idx in (RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE):
            visibility[idx] = right_visibility

        return PoseResult(pixel_xy=np.zeros((33, 2)), visibility=visibility, world_xyz=world)

    def test_both_sides_visible_matches_straight_standing(self) -> None:
        """정면(양쪽 다 잘 보임) 케이스는 가중평균을 넣기 전과 동일하게 나와야 한다."""
        features = compute_features(self._standing_pose(right_visibility=1.0))
        self.assertTrue(features.valid)
        self.assertAlmostEqual(features.trunk_flexion_3d, 0.0, places=3)
        self.assertAlmostEqual(features.knee_mean_3d, 180.0, places=3)

    def test_occluded_side_no_longer_rejected_and_is_downweighted(self) -> None:
        """옆모습처럼 한쪽 가시성이 낮으면(0.1, 기존 임계값 0.6 미달) 예전엔
        전체가 Unknown이 됐다. 이제는 보이는 쪽(왼쪽, 곧게 편 다리=180)을
        신뢰하고, 가려진 쪽의 잘못된 추정(무릎이 굽은 것처럼 보이는 좌표)에는
        거의 안 끌려가야 한다."""
        # 오른쪽(가려진 쪽) 무릎이 실제로는 안 굽었는데 MediaPipe가 굽었다고
        # 잘못 추정한 상황을 흉내낸다.
        bad_right_knee = (0.1, 0.4, 0.3)
        pose = self._standing_pose(right_visibility=0.1, right_knee_world=bad_right_knee)

        features = compute_features(pose)

        self.assertTrue(features.valid, "예전 기준(0.6)이면 무효 처리됐을 프레임이 이제는 유효해야 함")
        # 단순 평균이었다면 (180 + 잘못된 값)/2로 크게 떨어졌을 것. 가중평균이라
        # 신뢰도 높은(가시성 1.0) 왼쪽 180도 쪽으로 대부분 남아있어야 한다.
        self.assertGreater(features.knee_mean_3d, 170.0)

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

    def test_cumulative_bend_reported_only_at_session_end_not_live(self) -> None:
        """2026-09-15 결정: 누적 전방굴곡 위험(Frankel 등)은 실시간 라벨을
        더 이상 안 바꾼다. report.py용으로 세션 종료 시에만 별도 이벤트로
        기록한다 — 실시간 화면(get_live_state)에는 이 개념이 안 보여야 한다."""
        manager, events = self._make_manager()
        user_id = uuid.uuid4()
        session_id = manager.start_session(user_id)
        manager.set_calibration(session_id, CalibrationProfile(10, 175, 45, 0))

        # trunk_dev=0(Standing, 라벨은 원래도 Normal)이지만 trunk_flexion_abs는
        # 절대 30도 이상으로 계속 보내서 누적 임계값(데모 10초)을 넘긴다.
        last_state = None
        for t in range(12):
            last_state = manager.update_judgement(
                session_id, t=float(t), valid=True, trunk_dev=0, knee_dev=0, trunk_flexion_abs=35.0
            )

        self.assertEqual(last_state.burden_label, BurdenLabel.NORMAL)
        self.assertEqual(events.list_events(user_id), [])  # 세션 끝나기 전엔 아직 기록 안 됨

        live_before_end = manager.get_live_state(session_id)
        self.assertEqual(live_before_end.tallies, [])  # 실시간 집계에도 안 섞여 들어감

        manager.end_session(session_id)

        recorded = events.list_events(user_id)
        cumulative_events = [e for e in recorded if e.trigger_reason == EventTrigger.CUMULATIVE_RESEARCH_THRESHOLD]
        self.assertEqual(len(cumulative_events), 1)
        self.assertGreaterEqual(cumulative_events[0].duration_sec, 10.0)
        self.assertEqual(cumulative_events[0].posture_type, PostureType.BENDING)


if __name__ == "__main__":
    unittest.main()
