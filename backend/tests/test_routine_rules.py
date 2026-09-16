import unittest

from app.services.routine.rules import EFFECTS, apply_rules, load_rules


class RoutineRulesTest(unittest.TestCase):
    def test_yaml_is_well_formed(self) -> None:
        rules = load_rules()
        self.assertGreaterEqual(len(rules), 5)
        for rule in rules:
            self.assertIn(rule["effect"], EFFECTS)
            self.assertIn(rule["category"], ("meal", "household", "health", "sleep"))
            self.assertIn(":", rule["target"])

    def test_waist_pain_excludes_walk(self) -> None:
        result = apply_rules({"waist_pain": 4})
        self.assertIn("activity:walk", [c["target"] for c in result["exclude"]])
        self.assertNotIn("activity:walk", [c["target"] for c in apply_rules({"waist_pain": 3})["exclude"]])

    def test_allergy_and_diagnosis(self) -> None:
        result = apply_rules(
            {"allergies": ["갑각류"], "medical_conditions": ["임신성 당뇨 경계"], "week": 10}
        )
        self.assertEqual([c["target"] for c in result["exclude"]], ["ingredient:갑각류"])
        self.assertEqual([c["target"] for c in result["limit"]], ["nutrient:단순당"])

    def test_multiple_pregnancy_and_conjunction(self) -> None:
        early = apply_rules({"week": 19, "is_multiple_pregnancy": True})
        self.assertNotIn("chore:heavy_lifting", [c["target"] for c in early["exclude"]])
        mid = apply_rules({"week": 20, "is_multiple_pregnancy": True})
        self.assertIn("chore:heavy_lifting", [c["target"] for c in mid["exclude"]])
        # 28주 이상 + 쌍태: 두 규칙이 같은 target → 한 번만
        late = apply_rules({"week": 30, "is_multiple_pregnancy": True})
        self.assertEqual([c["target"] for c in late["exclude"]].count("chore:heavy_lifting"), 1)

    def test_empty_facts_only_defaults(self) -> None:
        result = apply_rules({})
        self.assertEqual(result, {"exclude": [], "limit": [], "require": []})


if __name__ == "__main__":
    unittest.main()
