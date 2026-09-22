"""챗봇 S1 공통 컨텍스트 테스트(AI·DB 호출 없음). 설계: docs/chatbot/chatbot_guide.md S1."""

import unittest
from datetime import date
from types import SimpleNamespace

from app.domains.chat.context import banner_text, collect_context
from app.services.routine.inputs import ProfileMissingError

TODAY = date(2026, 9, 22)
USER = "wife-1"


class FakeQuery:
    """select/eq/order/limit/execute만 흉내 낸다. eq 조건으로 행을 거른다."""

    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    def select(self, *_columns):
        return self

    def eq(self, column, value):
        return FakeQuery([row for row in self.rows if row.get(column) == value])

    def order(self, column):
        return FakeQuery(sorted(self.rows, key=lambda row: row[column]))

    def limit(self, count):
        return FakeQuery(self.rows[:count])

    def execute(self):
        return SimpleNamespace(data=self.rows)


class FakeClient:
    def __init__(self, tables: dict[str, list[dict]]) -> None:
        self.tables = tables

    def table(self, name):
        return FakeQuery(self.tables.get(name, []))


PROFILE = {
    "user_id": USER, "due_date": "2027-02-01", "is_first_pregnancy": True, "is_multiple_pregnancy": False,
    "allergies": ["갑각류"], "medical_conditions": ["임신성 당뇨 경계"], "medical_note": None,
}
CONDITION = {
    "user_id": USER, "date": TODAY.isoformat(), "nausea": 4, "waist_pain": 5, "pelvis_pain": 2,
    "leg_pain": 1, "wrist_pain": 1, "fatigue": 3, "mood": 1, "planned_activities": ["빨래"],
}
ITEMS = [
    {"user_id": USER, "date": TODAY.isoformat(), "category": "meal", "title": "계란찜 + 누룽지", "sort_order": 1, "change_kind": None},
    {"user_id": USER, "date": TODAY.isoformat(), "category": "meal", "title": "옛 메뉴", "sort_order": 2, "change_kind": "removed"},
    {"user_id": USER, "date": TODAY.isoformat(), "category": "sleep", "title": "23시 취침", "sort_order": 3, "change_kind": None},
]


class CollectContextTest(unittest.TestCase):
    def test_with_condition(self) -> None:
        context = collect_context(FakeClient({"pregnancy_profiles": [PROFILE], "daily_conditions": [CONDITION], "routine_items": ITEMS}), USER, TODAY)
        facts = context["facts"]
        self.assertEqual(facts["nausea"], 4)
        self.assertNotIn("mood", facts)                 # 09-22 회의 결정
        self.assertNotIn("planned_activities", facts)   # 챗봇 컨텍스트 밖
        self.assertEqual(context["guides"]["meal"], ["계란찜 + 누룽지"])  # removed 제외
        self.assertEqual(context["guides"]["household"], [])

    def test_without_condition_uses_profile_only(self) -> None:
        context = collect_context(FakeClient({"pregnancy_profiles": [PROFILE]}), USER, TODAY)
        self.assertIsNone(context["facts"]["nausea"])
        self.assertEqual(context["facts"]["allergies"], ["갑각류"])
        self.assertTrue(all(titles == [] for titles in context["guides"].values()))  # 루틴 없음 = 빈 목록

    def test_profile_missing_raises(self) -> None:
        with self.assertRaises(ProfileMissingError):
            collect_context(FakeClient({}), USER, TODAY)


class BannerTest(unittest.TestCase):
    def test_only_severe_conditions_and_profile(self) -> None:
        facts = {"week": 18, "nausea": 4, "waist_pain": 5, "pelvis_pain": 2, "fatigue": 3,
                 "medical_conditions": ["임신성 당뇨 경계"], "allergies": ["갑각류"]}
        self.assertEqual(banner_text(facts), "임신 18주차 · 입덧 심함 · 허리 통증 · 임신성 당뇨 경계 · 갑각류 알레르기")

    def test_no_condition(self) -> None:
        self.assertEqual(banner_text({"week": 18, "nausea": None}), "임신 18주차")


if __name__ == "__main__":
    unittest.main()
