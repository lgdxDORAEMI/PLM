import unittest

import numpy as np

from backend.app.services.movement.calibration import CalibrationProfile
from backend.app.services.movement.features import compute_features, three_point_angle
from backend.app.services.movement.pose_extractor import PoseResult
from backend.app.services.movement.rule_engine import RuleEngine
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


if __name__ == "__main__":
    unittest.main()
