"""S2: 재생성 diff·완료 체크 이어받기 단위 테스트 (DB·OpenAI 없음)."""

import unittest

from app.services.routine.diff import carry_over, diff_items


def item(key, title="제목", payload=None, **extra):
    return {"item_key": key, "title": title, "description": None, "payload": payload or {}, **extra}


class DiffItemsTest(unittest.TestCase):
    def test_added_updated_removed_unchanged(self) -> None:
        old = [item("meal:breakfast"), item("meal:lunch", "닭가슴살"), item("household:laundry")]
        new = [item("meal:breakfast"), item("meal:lunch", "두부조림"), item("health:leg")]
        self.assertEqual(
            diff_items(old, new),
            {"added": ["health:leg"], "updated": ["meal:lunch"], "removed": ["household:laundry"],
             "unchanged": ["meal:breakfast"]},
        )

    def test_source_ids_only_change_is_unchanged(self) -> None:
        """근거 문단만 바뀐 것은 사용자에게 변경이 아니다."""
        old = [item("sleep:main", source_ids=[1], sort_order=0)]
        new = [item("sleep:main", source_ids=[7], sort_order=3)]
        self.assertEqual(diff_items(old, new)["unchanged"], ["sleep:main"])

    def test_only_description_or_payload_change_is_unchanged(self) -> None:
        """AI가 설명 문장만 새로 쓴 것은 변경이 아니다(이름이 같으면 그대로)."""
        old = [item("meal:lunch", "두부조림", payload={"reason": "단백질 보충"})]
        new = [{**item("meal:lunch", "두부조림", payload={"reason": "식물성 단백질로 속이 편함"}), "description": "새 설명"}]
        self.assertEqual(diff_items(old, new)["unchanged"], ["meal:lunch"])

    def test_first_routine_is_all_added(self) -> None:
        new = [item("meal:lunch"), item("sleep:main")]
        self.assertEqual(diff_items([], new)["added"], ["meal:lunch", "sleep:main"])

    def test_duplicate_item_key_keeps_first(self) -> None:
        new = [item("meal:lunch", "먼저"), item("meal:lunch", "나중")]
        self.assertEqual(diff_items([item("meal:lunch", "먼저")], new),
                         {"added": [], "updated": [], "removed": [], "unchanged": ["meal:lunch"]})


class CarryOverTest(unittest.TestCase):
    def setUp(self) -> None:
        self.old = [
            item("meal:breakfast", status="completed", completed_at="2026-09-18T08:00:00Z", completed_by="wife"),
            item("meal:lunch", "닭가슴살", status="completed", completed_at="2026-09-18T12:00:00Z", completed_by="wife"),
        ]

    def test_keeps_status_by_item_key_even_if_title_changes(self) -> None:
        """완료는 끼니·부위·가사 슬롯 기준. 제목이 바뀌어도 같은 키면 유지하고 change_kind로만 알린다."""
        new = [item("meal:breakfast"), item("meal:lunch", "두부조림"), item("health:leg")]
        out = {e["item_key"]: e for e in carry_over(self.old, new)}
        self.assertEqual(out["meal:breakfast"]["status"], "completed")
        self.assertEqual(out["meal:breakfast"]["completed_by"], "wife")
        self.assertIsNone(out["meal:breakfast"]["change_kind"])
        self.assertEqual(out["meal:lunch"]["status"], "completed")      # 제목 변경에도 완료 유지
        self.assertEqual(out["meal:lunch"]["change_kind"], "updated")
        self.assertNotIn("status", out["health:leg"])                  # 새 항목은 미완료로 시작
        self.assertEqual(out["health:leg"]["change_kind"], "added")

    def test_first_routine_all_added(self) -> None:
        out = carry_over([], [item("sleep:main")])
        self.assertEqual([e["change_kind"] for e in out], ["added"])


if __name__ == "__main__":
    unittest.main()
