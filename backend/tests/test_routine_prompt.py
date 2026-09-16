import unittest

from app.services.routine.prompt import ROUTINE_SCHEMA, build_user_prompt


def _walk(node, path="$"):
    if isinstance(node, dict):
        if node.get("type") == "object":
            yield path, node
        for k, v in node.items():
            yield from _walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _walk(v, f"{path}[{i}]")


class RoutinePromptTest(unittest.TestCase):
    def test_schema_is_strict_compatible(self) -> None:
        """OpenAI strict 모드: 모든 객체는 additionalProperties=false, required = 모든 속성."""
        for path, obj in _walk(ROUTINE_SCHEMA):
            self.assertIs(obj.get("additionalProperties"), False, path)
            self.assertEqual(set(obj["required"]), set(obj["properties"]), path)
        self.assertEqual(set(ROUTINE_SCHEMA["properties"]), {"meal", "household", "health", "sleep"})

    def test_prompt_sections(self) -> None:
        facts = {"week": 24, "waist_pain": 4}
        bare = build_user_prompt(facts)
        self.assertIn("사용자 정보", bare)
        self.assertNotIn("확정 규칙", bare)
        self.assertNotIn("참고 문단", bare)
        full = build_user_prompt(
            facts,
            {"exclude": [{"category": "health", "target": "activity:walk", "reason": "허리"}], "limit": [], "require": []},
            [{"id": 7, "category": "통증", "content": "허리 통증 시 좌측위."}],
        )
        self.assertIn("activity:walk", full)
        self.assertIn("[id=7]", full)


if __name__ == "__main__":
    unittest.main()
