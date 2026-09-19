"""웬즈데이 AI S9(R6) impact 판단 테스트. §2.8 완료 확인 사례를 고정한다(AI·DB 없음)."""

import unittest

from app.services.routine.impact import resolve_impact

BASE = {"nausea": 3, "waist_pain": 2, "pelvis_pain": 1, "leg_pain": 1, "wrist_pain": 3, "fatigue": 2, "mood": 3}
CHORES = [{"code": "laundry", "label": "빨래"}]


def run(changes: dict, chores: bool = False) -> dict:
    activities = CHORES if chores else []
    previous = {**BASE, "planned_activities": activities}
    current = {**BASE, **changes, "planned_activities": activities}
    return resolve_impact(previous, current)


def modes(result: dict) -> dict:
    return {c: v["mode"] for c, v in result["category_impacts"].items()}


class ImpactCaseTest(unittest.TestCase):
    def test_no_change_keeps_all(self) -> None:
        """허리 3→3(값 그대로): 네 카테고리 KEEP."""
        same = {**BASE, "waist_pain": 3, "planned_activities": CHORES}
        result = resolve_impact(same, same)
        self.assertEqual(result["changed_conditions"], [])
        self.assertEqual(set(modes(result).values()), {"KEEP"})

    def test_small_waist_worsening_tunes_health_only(self) -> None:
        """허리 2→3(예정 가사 없음): health=TUNE, 나머지 KEEP."""
        result = run({"waist_pain": 3})
        self.assertEqual(modes(result), {"meal": "KEEP", "household": "KEEP", "health": "TUNE", "sleep": "KEEP"})
        self.assertEqual(result["category_impacts"]["health"]["strength"], "low")

    def test_waist_crossing_4_replans_health_household_depends_on_chores(self) -> None:
        """허리 3→4: health=REPLAN. 가사는 예정 가사가 있으면 TUNE, 없으면 KEEP."""
        base = {**BASE, "waist_pain": 3}
        without = resolve_impact({**base, "planned_activities": []}, {**base, "waist_pain": 4, "planned_activities": []})
        with_chores = resolve_impact({**base, "planned_activities": CHORES}, {**base, "waist_pain": 4, "planned_activities": CHORES})
        self.assertEqual(without["category_impacts"]["health"]["mode"], "REPLAN")
        self.assertTrue(without["changed_conditions"][0]["threshold_crossed"])
        self.assertEqual(without["category_impacts"]["household"]["mode"], "KEEP")
        self.assertEqual(with_chores["category_impacts"]["household"]["mode"], "TUNE")

    def test_nausea_3_to_5_replans_meal_and_health(self) -> None:
        """입덧 3→5: meal=REPLAN, 건강 보조 대책 health=REPLAN, 가사·수면 KEEP."""
        result = run({"nausea": 5}, chores=True)
        self.assertEqual(modes(result), {"meal": "REPLAN", "household": "KEEP", "health": "REPLAN", "sleep": "KEEP"})
        self.assertEqual(result["changed_conditions"][0]["impact"], 4)  # 2칸 2 + 4경계 1 + 5경계 1

    def test_combined_changes_accumulate_without_cancelling(self) -> None:
        """허리 2→3 + 손목 3→4 + 입덧 3→2: §2.5 JSON 예시와 같은 값."""
        changes = {"waist_pain": 3, "wrist_pain": 4, "nausea": 2}
        health = run(changes)["category_impacts"]["health"]
        self.assertEqual(
            (health["mode"], health["strength"], health["direction"], health["worsening_pressure"], health["improvement_pressure"]),
            ("REPLAN", "high", "worsened", 3.0, 0.5),
        )
        self.assertEqual(sorted(health["contributors"]), ["nausea", "waist_pain", "wrist_pain"])
        meal = run(changes)["category_impacts"]["meal"]
        self.assertEqual((meal["mode"], meal["strength"], meal["direction"]), ("TUNE", "low", "improved"))
        household = run(changes, chores=True)["category_impacts"]["household"]
        self.assertEqual((household["mode"], household["strength"], household["worsening_pressure"]), ("TUNE", "medium", 1.5))
        self.assertEqual(run(changes)["category_impacts"]["household"]["mode"], "KEEP")
        self.assertEqual(run(changes, chores=True)["category_impacts"]["sleep"]["mode"], "KEEP")

    def test_big_improvement_and_big_worsening_is_mixed(self) -> None:
        """허리 4→2(크게 호전) + 손목 2→4(크게 악화): health=mixed, 압력 각각 3."""
        previous = {**BASE, "waist_pain": 4, "wrist_pain": 2, "planned_activities": []}
        current = {**BASE, "waist_pain": 2, "wrist_pain": 4, "planned_activities": []}
        health = resolve_impact(previous, current)["category_impacts"]["health"]
        self.assertEqual((health["direction"], health["worsening_pressure"], health["improvement_pressure"]), ("mixed", 3.0, 3.0))
        self.assertEqual(health["mode"], "REPLAN")


class ImpactRuleTest(unittest.TestCase):
    def test_mood_scale_is_reversed(self) -> None:
        """기분은 클수록 좋음: 3→1은 악화(나쁨 3→5), 4는 호전. 경계도 뒤집어 센다."""
        result = run({"mood": 1})  # 3→1: 나쁨 3→5, 2칸 + 4경계 + 5경계
        self.assertEqual(result["changed_conditions"][0]["direction"], "worsened")
        self.assertEqual(result["changed_conditions"][0]["impact"], 4)
        self.assertEqual(modes(result)["sleep"], "REPLAN")
        self.assertEqual(run({"mood": 4})["changed_conditions"][0]["direction"], "improved")

    def test_activity_change_replans_household_only(self) -> None:
        previous = {**BASE, "planned_activities": CHORES}
        current = {**BASE, "planned_activities": [*CHORES, {"code": "cleaning", "label": "청소"}]}
        result = resolve_impact(previous, current)
        self.assertEqual(modes(result), {"meal": "KEEP", "household": "REPLAN", "health": "KEEP", "sleep": "KEEP"})
        self.assertEqual(result["category_impacts"]["household"]["contributors"], ["planned_activities"])

    def test_unchanged_items_are_not_contributors(self) -> None:
        result = run({"fatigue": 3}, chores=True)
        self.assertEqual([c["key"] for c in result["changed_conditions"]], ["fatigue"])
        for impact in result["category_impacts"].values():
            self.assertTrue(set(impact["contributors"]) <= {"fatigue"})


if __name__ == "__main__":
    unittest.main()
