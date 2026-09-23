"""홈 주차 특징 블록 테스트(FUC-W-HOME-001 ①). AI·DB 호출 없음."""

import unittest
from datetime import date
from types import SimpleNamespace

from unittest.mock import patch

from app.api.v1.routine import read_home_context
from app.services.routine.home import current_week, home_block, load_bands, week_band


class WeekNotesTest(unittest.TestCase):
    def test_bands_cover_1_to_40_without_gaps(self) -> None:
        covered = [w for b in load_bands() for w in range(b["weeks"][0], b["weeks"][1] + 1)]
        self.assertEqual(covered, list(range(1, 41)))
        self.assertTrue(all(len(b["notes"]) == 2 and b["caution"] for b in load_bands()))

    def test_week_28_matches_design_and_edges(self) -> None:
        self.assertEqual(week_band(28)["notes"][0], "배가 빠르게 커지면서 허리·골반 부담이 늘어요")
        self.assertEqual(week_band(0)["weeks"], [1, 4])
        self.assertEqual(week_band(42)["weeks"], [37, 40])

    def test_caution_prefers_ai_tip_then_band_default(self) -> None:
        with_tip = home_block(28, {"tip": {"text": "30분마다 앉아 쉬어 주세요", "source_ids": []}})
        self.assertEqual(with_tip["caution"], "30분마다 앉아 쉬어 주세요")
        fallback = home_block(28, {"tip": None})
        self.assertEqual(fallback["caution"], "오래 서 있는 자세와 무거운 물건은 주의해주세요")
        empty = home_block(None, {})
        self.assertEqual((empty["week"], empty["week_notes"], empty["caution"]), (None, [], None))

    def test_summaries_are_fixed_text(self) -> None:
        """09-22 팀 결정: 홈 카드 4장 문구는 고정. 루틴 응답에 무엇이 있어도 fallback.yaml 문구를 쓴다."""
        block = home_block(28, {"summaries": {"meal": "AI 문구"}})
        self.assertEqual(block["summaries"], {
            "meal": "오늘 컨디션에 맞춘 편한 식사로", "household": "무리한 집안일은 나누거나 가전에 맡기고",
            "health": "몸에 부담 없는 가벼운 움직임으로", "sleep": "편안한 잠자리 환경을 준비해요",
        })

    def test_current_week_from_due_date(self) -> None:
        rows = [{"due_date": "2026-12-10"}]
        query = SimpleNamespace(select=lambda *_: query, eq=lambda *_: query, limit=lambda *_: query,
                                execute=lambda: SimpleNamespace(data=rows))
        client = SimpleNamespace(table=lambda _: query)
        self.assertEqual(current_week(client, "u", date(2026, 9, 22)), 28)
        rows.clear()
        self.assertIsNone(current_week(client, "u", date(2026, 9, 22)))

    def test_home_context_does_not_require_a_daily_routine(self) -> None:
        service = SimpleNamespace(supabase=object())
        user = SimpleNamespace(id="wife-1")
        with (
            patch("app.api.v1.routine.home.current_week", return_value=28),
            patch("app.api.v1.routine.repository.get_routine", return_value=None),
        ):
            result = read_home_context(user, service)
        self.assertEqual(result["week"], 28)
        self.assertEqual(len(result["week_notes"]), 2)
        self.assertTrue(result["caution"])


if __name__ == "__main__":
    unittest.main()
