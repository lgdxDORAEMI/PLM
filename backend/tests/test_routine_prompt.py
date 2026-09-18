import unittest

from app.services.routine.prompt import (
    CATEGORIES,
    HEALTH_KEYS,
    MEAL_KEYS,
    ROUTINE_SCHEMA,
    SLEEP_KEY,
    build_user_prompt,
    category_schema,
)


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
        for schema in (ROUTINE_SCHEMA, *(category_schema(c) for c in CATEGORIES)):
            for path, obj in _walk(schema):
                self.assertIs(obj.get("additionalProperties"), False, path)
                self.assertEqual(set(obj["required"]), set(obj["properties"]), path)
        self.assertEqual(set(ROUTINE_SCHEMA["properties"]), {"meal", "household", "health", "sleep"})

    def test_item_key_is_fixed_set(self) -> None:
        """diff(R2)가 item_key로 비교하므로 호출마다 같은 값이어야 한다. household는 코드표 미확정 → 자유."""
        props = ROUTINE_SCHEMA["properties"]
        self.assertEqual(props["meal"]["items"]["properties"]["item_key"]["enum"], list(MEAL_KEYS))
        self.assertEqual(props["health"]["items"]["properties"]["item_key"]["enum"], list(HEALTH_KEYS))
        self.assertEqual(props["sleep"]["properties"]["item_key"]["enum"], [SLEEP_KEY])
        self.assertNotIn("enum", props["household"]["items"]["properties"]["item_key"])
        self.assertIn("household:<영문 소문자 활동코드>", __import__("app.services.routine.prompt", fromlist=["x"]).SYSTEM_PROMPT)

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
