"""챗봇 S5·S6 식사 모드 테스트(가짜 Supabase·OpenAI, 실호출 없음). 설계: docs/chatbot/chatbot_guide.md S5·S6.

확인: 식사 메모리 4종이 지시문에 들어간다 / 추천 카드 저장·조회 / 금지 재료 카드 차단 / 일반 모드는 카드 없음 /
같은 날짜 대화 전체가 이력으로 넘어간다 / 루틴·피드백 테이블에 쓰지 않는다 / 카드가 Care API 입력 모양과 맞는다.
"""

import json
import unittest
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from app.domains.care.schemas import RoutineItemUpdateInput
from app.domains.chat.meal_memory import BANNED_REPLY, CARD_ACTIONS
from app.domains.chat.responder import MEAL_REPLY_SCHEMA, REPLY_SCHEMA
from app.domains.chat.schemas import ChatMessageInput, MealAlternativeInput
from app.domains.chat.service import ChatService
from app.domains.chat.supabase_repository import SupabaseChatRepository
from app.domains.errors import DomainStorageError

TODAY = date(2026, 9, 22)
USER = "wife-1"
ITEM = "item-breakfast"
CARD = {"title": "찐 감자 + 플레인 요거트", "reason": "냄새가 거의 없어요.", "nutritionTags": ["냄새 없음"], "cautions": []}
CONTEXT = {
    "facts": {"week": 27, "allergies": ["갑각류"], "medical_conditions": [], "nausea": 4},
    "guides": {"meal": ["계란찜 + 누룽지"], "household": [], "health": [], "sleep": []},
}


class FakeQuery:
    def __init__(self, db, name):
        self.db, self.name, self.filters, self.sort, self.n, self.row = db, name, [], None, None, None

    def select(self, *_):
        return self

    def eq(self, c, v):
        self.filters.append(lambda r: r.get(c) == v)
        return self

    def in_(self, c, vs):
        self.filters.append(lambda r: r.get(c) in vs)
        return self

    def order(self, c, desc=False):
        self.sort = (c, desc)
        return self

    def limit(self, n):
        self.n = n
        return self

    def insert(self, row):
        self.row = row
        return self

    def execute(self):
        rows = self.db.setdefault(self.name, [])
        if self.row is not None:
            new = {"id": str(uuid4()), "created_at": (datetime(2026, 9, 22, tzinfo=timezone.utc)
                   + timedelta(seconds=len(rows))).isoformat(), **self.row}
            rows.append(new)
            self.db.setdefault("_writes", []).append(self.name)
            return SimpleNamespace(data=[new])
        out = [r for r in rows if all(f(r) for f in self.filters)]
        if self.sort:
            out.sort(key=lambda r: r[self.sort[0]], reverse=self.sort[1])
        return SimpleNamespace(data=out[: self.n] if self.n else out)


class FakeClient:
    def __init__(self):
        self.db = {
            "routine_items": [{"id": ITEM, "user_id": USER, "date": TODAY.isoformat(), "category": "meal",
                               "title": "계란찜 + 누룽지",
                               "payload": {"reason": "입덧에 순한 조합", "nutritionTags": ["단백질 풍부"],
                                           "cautions": [{"title": "커피"}]}}],
            "recommendation_feedback": [
                {"user_id": USER, "kind": "meal_reject", "payload": {"title": "미역국"}, "created_at": "2026-09-21T01:00:00"},
                {"user_id": USER, "kind": "sleep_env_override", "payload": {"temperature": 24}, "created_at": "2026-09-21T02:00:00"},
            ],
        }

    def table(self, name):
        return FakeQuery(self.db, name)


class FakeGenerator:
    def __init__(self, reply):
        self.reply, self.calls = reply, []

    async def generate(self, prompt, schema, name, system):
        self.calls.append((prompt, schema))
        return json.dumps(self.reply, ensure_ascii=False)


class FakeRetriever:
    async def search(self, text, week):
        return []


async def send(client, reply, content="냄새가 부담돼요", item=ITEM):
    generator = FakeGenerator(reply)
    service = ChatService(SupabaseChatRepository(client), client=client, generator=generator, retriever=FakeRetriever())
    with patch("app.domains.chat.service.collect_context", return_value=CONTEXT):
        message = await service.send_message(USER, TODAY, ChatMessageInput(content=content, routine_item_id=item))
    return message, generator


class MealModeTest(unittest.IsolatedAsyncioTestCase):
    async def test_meal_memory_in_prompt_and_card_saved(self) -> None:
        client = FakeClient()
        message, generator = await send(client, {"content": "냄새 없는 걸로 골랐어요.", "suggested_actions": ["x"], "recommendation": CARD})
        prompt, schema = generator.calls[0]
        self.assertIs(schema, MEAL_REPLY_SCHEMA)
        self.assertIn("[보던 끼니] 계란찜 + 누룽지 / 이유: 입덧에 순한 조합", prompt)   # 메모리 1
        self.assertIn("[금지 재료] 갑각류", prompt)                                   # 메모리 2
        self.assertIn("[과거 메뉴 선택] 안 고름: 미역국", prompt)                        # 메모리 3 (수면 기록 제외)
        self.assertNotIn("temperature", prompt)
        self.assertIn("오늘 다른 끼니 메뉴다. 선택지가 아니다", prompt)            # 09-22 실호출: 점심·저녁 메뉴 재사용 방지
        self.assertEqual(message.recommendation, CARD)
        self.assertEqual(message.suggested_actions, CARD_ACTIONS)                     # 버튼은 서버 고정(S6)
        self.assertEqual(client.db["chat_messages"][-1]["recommendation"], CARD)
        self.assertEqual(set(client.db["_writes"]), {"chat_messages"})                 # 루틴·피드백에 쓰지 않음

    async def test_banned_card_is_dropped_with_fixed_reply(self) -> None:
        client = FakeClient()
        shrimp = {**CARD, "title": "갑각류 새우볶음밥"}
        message, _ = await send(client, {"content": "새우볶음밥 어때요?", "suggested_actions": [], "recommendation": shrimp})
        self.assertEqual((message.content, message.recommendation, message.suggested_actions), (BANNED_REPLY, None, []))

    async def test_question_without_card_keeps_llm_actions(self) -> None:
        message, _ = await send(FakeClient(), {"content": "계란은 괜찮아요.", "suggested_actions": [], "recommendation": None})
        self.assertIsNone(message.recommendation)
        self.assertEqual(message.suggested_actions, [])

    async def test_tab_mode_uses_plain_schema_and_no_card_column(self) -> None:
        client = FakeClient()
        message, generator = await send(client, {"content": "답", "suggested_actions": []}, content="질문", item=None)
        self.assertIs(generator.calls[0][1], REPLY_SCHEMA)
        self.assertIsNone(message.recommendation)
        self.assertNotIn("recommendation", client.db["chat_messages"][-1])  # migration 전에도 일반 대화 저장이 깨지지 않음

    async def test_history_is_whole_day_with_card_titles(self) -> None:
        client = FakeClient()
        await send(client, {"content": "탭 답", "suggested_actions": []}, content="요즘 냄새에 예민해요", item=None)
        await send(client, {"content": "추천해요.", "suggested_actions": [], "recommendation": CARD})
        _, generator = await send(client, {"content": "또", "suggested_actions": [], "recommendation": None}, content="다른 메뉴 보기")
        prompt = generator.calls[0][0]
        self.assertIn("user: 요즘 냄새에 예민해요", prompt)                   # 하단 탭 대화도 기억(같은 날짜)
        self.assertIn("assistant: 추천해요. [추천: 찐 감자 + 플레인 요거트]", prompt)  # 반복 추천 방지

    async def test_meal_alternative_returns_card_without_writes(self) -> None:
        """09-22 식사 가이드 '다른 메뉴 보기': 카드 1장, 대화 저장·루틴 변경 없음, 거절 기록이 지시문에 들어감."""
        client = FakeClient()
        generator = FakeGenerator({"content": "바꿔봤어요.", "suggested_actions": [], "recommendation": CARD})
        service = ChatService(SupabaseChatRepository(client), client=client, generator=generator, retriever=FakeRetriever())
        with patch("app.domains.chat.service.collect_context", return_value=CONTEXT):
            card = await service.meal_alternative(USER, TODAY, MealAlternativeInput(routine_item_id=ITEM))
        self.assertEqual((card.routine_item_id, card.title), (ITEM, CARD["title"]))
        prompt = generator.calls[0][0]
        self.assertIn("'다른 메뉴 보기' 버튼이다. recommendation은 반드시 1개", prompt)
        self.assertIn("안 고름: 미역국", prompt)
        self.assertNotIn("_writes", client.db)

    async def test_meal_alternative_without_or_banned_card_is_503(self) -> None:
        for reply in ({"content": "음", "suggested_actions": [], "recommendation": None},
                      {"content": "새우", "suggested_actions": [], "recommendation": {**CARD, "title": "갑각류 새우찜"}}):
            client = FakeClient()
            service = ChatService(SupabaseChatRepository(client), client=client,
                                  generator=FakeGenerator(reply), retriever=FakeRetriever())
            with patch("app.domains.chat.service.collect_context", return_value=CONTEXT), \
                    self.assertRaises(DomainStorageError):
                await service.meal_alternative(USER, TODAY, MealAlternativeInput(routine_item_id=ITEM))

    def test_card_fits_care_api_input(self) -> None:
        """S6: 사용자가 '이걸로 할게요'를 누르면 프론트가 카드를 그대로 Care API로 보낸다."""
        body = RoutineItemUpdateInput(feedback_kind="meal_replace", payload=CARD)
        self.assertEqual(body.payload["title"], CARD["title"])


if __name__ == "__main__":
    unittest.main()
