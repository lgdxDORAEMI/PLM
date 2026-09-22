"""챗봇 S2 응답 생성 테스트(가짜 OpenAI·검색, 실호출 없음). 설계: docs/chatbot/chatbot_guide.md S2."""

import asyncio
import json
import unittest

from app.domains.chat import responder
from app.domains.chat.responder import FALLBACK_REPLY, build_prompt, generate_reply

CONTEXT = {
    "facts": {"week": 18, "allergies": ["갑각류"], "nausea": 4, "fatigue": None},
    "guides": {"meal": ["계란찜 + 누룽지"], "household": [], "health": [], "sleep": []},
}
CHUNKS = [{"id": 1, "content": "임신 중 매운 음식은 속쓰림을 늘릴 수 있다."}]


class FakeGenerator:
    def __init__(self, result: str | Exception | None = None, delay: float = 0) -> None:
        self.result, self.delay, self.prompts = result, delay, []

    async def generate(self, prompt, schema, name, system):
        self.prompts.append(prompt)
        await asyncio.sleep(self.delay)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


class FakeRetriever:
    def __init__(self, fail: bool = False) -> None:
        self.fail, self.calls = fail, []

    async def search(self, text, week):
        self.calls.append((text, week))
        if self.fail:
            raise RuntimeError("rpc down")
        return CHUNKS


def ok(content="갑각류만 빼면 괜찮아요.", actions=("대체 메뉴 추천", "식사 가이드 보기", "셋째")):
    return json.dumps({"content": content, "suggested_actions": list(actions)}, ensure_ascii=False)


def run(generator, retriever=None, history=None, extra_rules=""):
    return asyncio.run(generate_reply(generator, retriever or FakeRetriever(), CONTEXT, "마라탕 먹어도 될까요?", history or [], extra_rules))


class GenerateReplyTest(unittest.TestCase):
    def test_ai_reply_with_actions_capped(self) -> None:
        retriever = FakeRetriever()
        reply = run(FakeGenerator(ok()), retriever)
        self.assertEqual(reply.source, "ai")
        self.assertEqual(reply.content, "갑각류만 빼면 괜찮아요.")
        self.assertEqual(reply.suggested_actions, ["대체 메뉴 추천", "식사 가이드 보기"])  # 최대 2개
        self.assertEqual(retriever.calls, [("마라탕 먹어도 될까요?", 18)])  # 질문·주차로 검색

    def test_api_error_falls_back(self) -> None:
        reply = run(FakeGenerator(RuntimeError("openai 500")))
        self.assertEqual((reply.source, reply.content, reply.suggested_actions), ("fallback", FALLBACK_REPLY, []))

    def test_bad_json_and_empty_content_fall_back(self) -> None:
        self.assertEqual(run(FakeGenerator("not json")).source, "fallback")
        self.assertEqual(run(FakeGenerator(ok(content="  "))).source, "fallback")

    def test_timeout_falls_back(self) -> None:
        original = responder.TOTAL_TIMEOUT_SEC
        responder.TOTAL_TIMEOUT_SEC = 0.01
        try:
            self.assertEqual(run(FakeGenerator(ok(), delay=0.1)).source, "fallback")
        finally:
            responder.TOTAL_TIMEOUT_SEC = original

    def test_search_failure_still_answers(self) -> None:
        generator = FakeGenerator(ok())
        reply = run(generator, FakeRetriever(fail=True))
        self.assertEqual(reply.source, "ai")
        self.assertIn("[참고 자료]\n없음", generator.prompts[0])


class BuildPromptTest(unittest.TestCase):
    def test_sections_history_limit_and_extra_rules(self) -> None:
        history = [{"role": "user", "content": f"q{i}"} for i in range(8)]
        prompt = build_prompt(CONTEXT, "질문", history, CHUNKS, extra_rules="메뉴 변경은 안내만")
        self.assertIn('"allergies": ["갑각류"]', prompt)
        self.assertIn("- 임신 중 매운 음식은", prompt)
        self.assertNotIn("q1\n", prompt)   # 최근 6개만(q2~q7)
        self.assertIn("user: q7", prompt)
        self.assertIn("[이 대화 추가 규칙]\n메뉴 변경은 안내만", prompt)
        self.assertTrue(prompt.endswith("[질문]\n질문"))


if __name__ == "__main__":
    unittest.main()
