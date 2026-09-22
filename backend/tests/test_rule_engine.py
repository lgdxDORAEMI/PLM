import tempfile
import unittest
import uuid
from datetime import timedelta
from pathlib import Path

from app.services.movement.calibration import LocalFileCalibrationStore
from app.services.movement.events import InMemoryEventStore
from app.services.movement.rule_engine import RuleEngine, compute_bending_threshold_deg
from app.services.movement.session_manager import SessionManager
from app.utils import dates


class ComputeBendingThresholdDegTest(unittest.TestCase):
    """임신 주수·체중 기반 Bending 판정 각도 개인화 공식 검증. 표 값은 오차 0.1도 이내."""

    def test_matches_reference_table(self) -> None:
        table = {
            45.0: {20: 18.6, 28: 17.1, 36: 15.9, 40: 15.4},
            55.0: {20: 18.8, 28: 17.6, 36: 16.5, 40: 16.1},
            70.0: {20: 19.0, 28: 18.1, 36: 17.2, 40: 16.8},
            90.0: {20: 19.3, 28: 18.5, 36: 17.7, 40: 17.4},
        }
        for weight, by_week in table.items():
            for week, expected in by_week.items():
                with self.subTest(weight=weight, week=week):
                    actual = compute_bending_threshold_deg(week, weight)
                    self.assertAlmostEqual(actual, expected, delta=0.1)

    def test_before_week_13_uses_base_deg_unchanged(self) -> None:
        for week in (0, 1, 12, 13):
            with self.subTest(week=week):
                self.assertEqual(compute_bending_threshold_deg(week, 60.0), 20.0)

    def test_custom_base_deg(self) -> None:
        # 13주 이전이면 조정이 없으니 base_deg를 그대로 돌려준다.
        self.assertEqual(compute_bending_threshold_deg(10, 60.0, base_deg=25.0), 25.0)


class RuleEngineBendingOverrideTest(unittest.TestCase):
    def test_no_override_uses_rules_yaml_default(self) -> None:
        engine = RuleEngine()
        self.assertEqual(engine.bending_trunk_dev_min, 20)

    def test_override_replaces_default(self) -> None:
        engine = RuleEngine(bending_trunk_dev_min_override=15.9)
        self.assertEqual(engine.bending_trunk_dev_min, 15.9)
        # 다른 임계값들은 override와 무관하게 rules.yaml 값 그대로여야 한다.
        self.assertEqual(engine.sitting_knee_dev_min, 40)


class SessionManagerBendingPersonalizationTest(unittest.TestCase):
    """start_session()의 개인화 배선: 프로필 값이 있으면 override, 없으면 fallback."""

    def _due_date_for_week(self, target_week: int):
        today = dates.today_kst()
        return today + timedelta(days=dates.FULL_TERM_DAYS - target_week * 7)

    def _make_manager(self) -> SessionManager:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        store = LocalFileCalibrationStore(base_dir=Path(tmp.name))
        return SessionManager(calibration_store=store, event_store=InMemoryEventStore())

    def test_weight_and_due_date_override_threshold(self) -> None:
        manager = self._make_manager()
        session_id = manager.start_session(
            uuid.uuid4(),
            pre_pregnancy_weight_kg=45.0,
            due_date=self._due_date_for_week(36),
        )
        engine = manager._sessions[session_id].rule_engine
        self.assertAlmostEqual(engine.bending_trunk_dev_min, 15.9, delta=0.1)

    def test_missing_weight_falls_back_to_default(self) -> None:
        manager = self._make_manager()
        session_id = manager.start_session(
            uuid.uuid4(), due_date=self._due_date_for_week(36)
        )
        engine = manager._sessions[session_id].rule_engine
        self.assertEqual(engine.bending_trunk_dev_min, 20)

    def test_missing_due_date_falls_back_to_default(self) -> None:
        manager = self._make_manager()
        session_id = manager.start_session(uuid.uuid4(), pre_pregnancy_weight_kg=45.0)
        engine = manager._sessions[session_id].rule_engine
        self.assertEqual(engine.bending_trunk_dev_min, 20)

    def test_no_profile_args_falls_back_to_default(self) -> None:
        manager = self._make_manager()
        session_id = manager.start_session(uuid.uuid4())
        engine = manager._sessions[session_id].rule_engine
        self.assertEqual(engine.bending_trunk_dev_min, 20)


if __name__ == "__main__":
    unittest.main()
