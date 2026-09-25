"""홈 주차 안내: RAG 생성·사용자별 일일 유지·폴백 테스트."""

import asyncio
import unittest
from datetime import date
from types import SimpleNamespace

from unittest.mock import patch

from app.api.v1.routine import read_home_context
from app.services.routine.home import (
    _validate_generated,
    current_week,
    home_block,
    load_bands,
    resolve_daily_guide,
    week_band,
)
from tests.test_routine_service import FakeSupabase


class FakeRetriever:
    def __init__(self, *, fail: bool = False) -> None:
        self.calls = 0
        self.fail = fail

    async def search_week_guide(self, week: int) -> list[dict]:
        self.calls += 1
        if self.fail:
            raise RuntimeError("rag down")
        return [{"id": 7, "category": "임신", "content": f"임신 {week}주 근거", "source": "OWH"}]


class FakeGenerator:
    def __init__(self) -> None:
        self.calls = 0

    async def generate_week_guide(self, week: int, chunks: list[dict]) -> dict:
        self.calls += 1
        return {
            "week_notes": [f"{week}주에는 몸의 변화가 나타날 수 있어요", "개인마다 느끼는 변화가 다를 수 있어요"],
            "caution": "불편한 변화가 있으면 의료진과 상담해 주세요",
            "source_ids": [7, 999],
        }


class WeekNotesTest(unittest.TestCase):
    def test_bands_cover_1_to_40_without_gaps(self) -> None:
        covered = [w for b in load_bands() for w in range(b["weeks"][0], b["weeks"][1] + 1)]
        self.assertEqual(covered, list(range(1, 41)))
        self.assertTrue(all(len(b["notes"]) == 2 and b["caution"] for b in load_bands()))

    def test_week_28_matches_design_and_edges(self) -> None:
        self.assertEqual(week_band(28)["notes"][0], "배가 빠르게 커지면서 허리·골반 부담이 늘어요")
        self.assertEqual(week_band(0)["weeks"], [1, 4])
        self.assertEqual(week_band(42)["weeks"], [37, 40])

    def test_home_block_uses_saved_daily_guide_and_exposes_sources(self) -> None:
        block = home_block(28, {
            "week_notes": ["첫 줄", "둘째 줄"], "caution": "주의 문구", "source": "rag",
            "source_ids": [7], "sources": [{"id": 7, "source": "OWH"}], "generated_at": "now",
        })
        self.assertEqual(block["week_notes"], ["첫 줄", "둘째 줄"])
        self.assertEqual(block["caution"], "주의 문구")
        self.assertEqual(block["source_ids"], [7])
        empty = home_block(None, None)
        self.assertEqual((empty["week"], empty["week_notes"], empty["caution"]), (None, [], None))

    def test_summaries_are_fixed_text(self) -> None:
        """09-22 팀 결정: 홈 카드 4장 문구는 고정. 루틴 응답에 무엇이 있어도 fallback.yaml 문구를 쓴다."""
        block = home_block(28, {"week_notes": ["1", "2"], "caution": "3"})
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

    def test_generated_guide_rejects_unknown_only_source_ids(self) -> None:
        chunks = [{"id": 7, "source": "OWH"}]
        with self.assertRaises(ValueError):
            _validate_generated({"week_notes": ["1", "2"], "caution": "3", "source_ids": [999]}, chunks)

    def test_daily_guide_is_generated_once_and_reused(self) -> None:
        db, retriever, generator = FakeSupabase(), FakeRetriever(), FakeGenerator()
        first = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 28, "model"))
        second = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 28, "model"))
        self.assertEqual(first["id"], second["id"])
        self.assertEqual((retriever.calls, generator.calls), (1, 1))
        self.assertEqual(first["source_ids"], [7])
        self.assertEqual(first["sources"], [{"id": 7, "source": "OWH"}])

    def test_generation_failure_is_saved_as_daily_fallback(self) -> None:
        db, retriever, generator = FakeSupabase(), FakeRetriever(fail=True), FakeGenerator()
        guide = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 28, "model"))
        again = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 28, "model"))
        self.assertEqual(guide["source"], "fallback")
        self.assertEqual(guide["source_ids"], [])
        self.assertEqual(guide["id"], again["id"])
        self.assertEqual(retriever.calls, 1)

    def test_same_day_profile_week_change_updates_the_single_row(self) -> None:
        db, retriever, generator = FakeSupabase(), FakeRetriever(), FakeGenerator()
        first = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 28, "model"))
        changed = asyncio.run(resolve_daily_guide(db, retriever, generator, "wife-1", date(2026, 9, 25), 29, "model"))
        self.assertEqual(first["id"], changed["id"])
        self.assertEqual(changed["pregnancy_week"], 29)
        self.assertEqual(len(db.tables["home_week_guides"]), 1)
        self.assertEqual((retriever.calls, generator.calls), (2, 2))

    def test_home_context_does_not_require_a_daily_routine(self) -> None:
        db = FakeSupabase()
        service = SimpleNamespace(
            supabase=db,
            retriever=FakeRetriever(),
            generator=FakeGenerator(),
            settings=SimpleNamespace(llm_model="model"),
        )
        user = SimpleNamespace(id="wife-1")
        with patch("app.api.v1.routine.home.current_week", return_value=28):
            result = asyncio.run(read_home_context(user, service))
        self.assertEqual(result["week"], 28)
        self.assertEqual(len(result["week_notes"]), 2)
        self.assertEqual(result["source"], "rag")


if __name__ == "__main__":
    unittest.main()
