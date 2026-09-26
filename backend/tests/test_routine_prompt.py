import unittest

from app.services.routine.prompt import (
    CATEGORIES,
    HEALTH_KEYS,
    HOUSEHOLD_KEYS,
    MEAL_KEYS,
    ROUTINE_SCHEMA,
    SLEEP_KEY,
    TIP_SCHEMA,
    WEEK_GUIDE_SCHEMA,
    WEEK_GUIDE_SYSTEM_PROMPT,
    build_week_guide_prompt,
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
        for schema in (ROUTINE_SCHEMA, TIP_SCHEMA, WEEK_GUIDE_SCHEMA, *(category_schema(c) for c in CATEGORIES)):
            for path, obj in _walk(schema):
                self.assertIs(obj.get("additionalProperties"), False, path)
                self.assertEqual(set(obj["required"]), set(obj["properties"]), path)
        self.assertEqual(set(ROUTINE_SCHEMA["properties"]), {"meal", "household", "health", "sleep"})

    def test_item_key_is_fixed_set(self) -> None:
        """diff(R2)가 item_key로 비교하므로 호출마다 같은 값이어야 한다. S6: household도 코드표 10종으로 고정."""
        props = ROUTINE_SCHEMA["properties"]
        self.assertEqual(props["meal"]["items"]["properties"]["item_key"]["enum"], list(MEAL_KEYS))
        self.assertEqual(props["health"]["items"]["properties"]["item_key"]["enum"], list(HEALTH_KEYS))
        self.assertEqual(props["sleep"]["properties"]["item_key"]["enum"], [SLEEP_KEY])
        self.assertEqual(props["household"]["items"]["properties"]["item_key"]["enum"], list(HOUSEHOLD_KEYS))
        self.assertEqual(len(HOUSEHOLD_KEYS), 10)
        self.assertIn("household:custom", HOUSEHOLD_KEYS)

    def test_tip_request_excludes_other_guides(self) -> None:
        """팁은 가이드와 겹치지 않는 생활 행동만. 스트레칭은 건강 가이드(영상) 몫."""
        from app.services.routine.prompt import TIP_REQUEST
        for word in ("스트레칭", "식사 메뉴", "집안일 분담", "취침 시각"):
            self.assertIn(word, TIP_REQUEST)
        self.assertIn("쓰지 않는다", TIP_REQUEST)

    def test_week_guide_requires_two_notes_and_rag_sources(self) -> None:
        notes = WEEK_GUIDE_SCHEMA["properties"]["week_notes"]
        self.assertEqual((notes["minItems"], notes["maxItems"]), (2, 2))
        self.assertIn("참고 문단에 직접 근거", WEEK_GUIDE_SYSTEM_PROMPT)
        prompt = build_week_guide_prompt(28, [{
            "id": 7, "category": "임신", "content": "근거 문단", "source": "OWH",
        }])
        self.assertIn("28주", prompt)
        self.assertIn("[id=7]", prompt)
        self.assertIn("출처=OWH", prompt)

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


class MealOutputLimitTest(unittest.TestCase):
    """K1: 가장 느린 식단 호출의 출력 분량을 지시문으로 제한한다(09-20)."""

    def test_meal_limits_in_system_prompt(self) -> None:
        from app.services.routine.prompt import SYSTEM_PROMPT

        for phrase in ("title 20자 이내", "60자 이내", "nutritionTags 3개 이내"):
            self.assertIn(phrase, SYSTEM_PROMPT)
        # 09-26: cautions는 분량 제한 대상이 아니라 끼니마다 1개 필수다
        # (화면 '오늘 조심할 것'이 늘 비어 있었다).
        self.assertIn("끼니마다 정확히 1개를 채운다(빈 배열 금지)", SYSTEM_PROMPT)
