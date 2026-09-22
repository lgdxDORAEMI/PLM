"""Chat 대화 이력이 Supabase에 실제로 저장되는지 확인한다(FUC-W-CHAT-004의
conversation history 저장). 실제 AI 응답 로직은 없다 — 고정 안내 문구가 그대로
저장·조회되는지, 그리고 매 요청 새 Repository 인스턴스를 만들어도(=서버
재시작을 흉내) 대화가 남아있는지만 검증한다. Stub(프로세스 메모리)은 이게
안 됐다.
"""

import unittest
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from httpx import ASGITransport, AsyncClient

from app.api.v1.chat import get_chat_service
from app.core.security import CurrentUser, get_current_user
from app.domains.chat.schemas import ChatMessageInput, ChatRole
from app.domains.chat.service import ChatService
from app.domains.chat.supabase_repository import PLACEHOLDER_REPLY, SupabaseChatRepository
from app.main import app

TARGET_DATE = date(2026, 9, 20)
USER_ID = "wife-1"


class FakeTable:
    """select().eq()...order()?.execute() / insert().execute()만 흉내 낸다."""

    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows
        self._filters: dict[str, object] = {}
        self._order: str | None = None
        self._op: str | None = None
        self._payload: dict | None = None

    def select(self, *_columns: str) -> "FakeTable":
        return self

    def eq(self, column: str, value) -> "FakeTable":
        self._filters[column] = value
        return self

    def order(self, column: str) -> "FakeTable":
        self._order = column
        return self

    def insert(self, row: dict) -> "FakeTable":
        self._op, self._payload = "insert", row
        return self

    def execute(self) -> SimpleNamespace:
        if self._op == "insert":
            new_row = {
                "id": str(uuid4()),
                "suggested_actions": None,
                "created_at": datetime.now(timezone.utc).isoformat(),
                **self._payload,
            }
            self._rows.append(new_row)
            return SimpleNamespace(data=[new_row])
        rows = [
            row for row in self._rows if all(row.get(k) == v for k, v in self._filters.items())
        ]
        if self._order:
            rows = sorted(rows, key=lambda row: row[self._order])
        return SimpleNamespace(data=rows)


class FakeSupabaseClient:
    def __init__(self) -> None:
        self.rows: list[dict] = []

    def table(self, name: str) -> FakeTable:
        assert name == "chat_messages"
        return FakeTable(self.rows)


class SupabaseChatRepositoryTest(unittest.TestCase):
    def test_add_message_persists_user_message_and_placeholder_reply(self) -> None:
        client = FakeSupabaseClient()
        repo = SupabaseChatRepository(client)

        reply = repo.add_message(
            USER_ID, TARGET_DATE, ChatMessageInput(content="다른 메뉴 추천해줘")
        )

        self.assertEqual(reply.role, ChatRole.ASSISTANT)
        self.assertEqual(reply.content, PLACEHOLDER_REPLY)
        self.assertEqual(len(client.rows), 2)
        self.assertEqual(client.rows[0]["role"], "user")
        self.assertEqual(client.rows[0]["content"], "다른 메뉴 추천해줘")

    def test_list_messages_returns_saved_history_in_order(self) -> None:
        client = FakeSupabaseClient()
        repo = SupabaseChatRepository(client)

        repo.add_message(USER_ID, TARGET_DATE, ChatMessageInput(content="첫 질문"))
        repo.add_message(USER_ID, TARGET_DATE, ChatMessageInput(content="두 번째 질문"))

        history = repo.list_messages(USER_ID, TARGET_DATE)
        self.assertEqual(
            [message.content for message in history],
            ["첫 질문", PLACEHOLDER_REPLY, "두 번째 질문", PLACEHOLDER_REPLY],
        )


class ChatApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.client = FakeSupabaseClient()
        app.dependency_overrides[get_chat_service] = lambda: ChatService(
            SupabaseChatRepository(self.client)
        )
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=USER_ID)
        self.addCleanup(app.dependency_overrides.clear)

    def http(self) -> AsyncClient:
        return AsyncClient(transport=ASGITransport(app=app), base_url="http://localhost")

    async def test_message_round_trip_survives_a_fresh_repository_instance(self) -> None:
        """새 요청마다 Repository를 새로 만들어도(=서버 재시작을 흉내) 대화가
        남아있어야 한다 — 프로세스 메모리 Stub이었다면 여기서 사라졌을 것이다."""
        async with self.http() as client:
            response = await client.post(
                "/api/v1/chat/messages", json={"content": "오늘 점심 메뉴 바꿀 수 있어?"}
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["content"], PLACEHOLDER_REPLY)

        async with self.http() as client:
            response = await client.get("/api/v1/chat/messages")
            self.assertEqual(response.status_code, 200)
            history = response.json()
            self.assertEqual(len(history), 2)
            self.assertEqual(history[0]["role"], "user")
            self.assertEqual(history[0]["content"], "오늘 점심 메뉴 바꿀 수 있어?")
            self.assertEqual(history[1]["role"], "assistant")

    async def test_live_reply_is_generated_and_saved_with_mode_history(self) -> None:
        class FakeGenerator:
            async def generate(self, prompt, schema, name, system):
                assert "첫 질문" in prompt
                return '{"content":"실제 생성된 답변","suggested_actions":[]}'

        class FakeRetriever:
            async def search(self, text, week):
                return []

        self.client.rows.extend([
            {
                "id": str(uuid4()), "user_id": USER_ID, "date": TARGET_DATE.isoformat(),
                "role": "user", "content": "첫 질문", "routine_item_id": None,
                "suggested_actions": None, "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": str(uuid4()), "user_id": USER_ID, "date": TARGET_DATE.isoformat(),
                "role": "user", "content": "다른 식사 대화", "routine_item_id": "meal-1",
                "suggested_actions": None, "created_at": datetime.now(timezone.utc).isoformat(),
            },
        ])
        service = ChatService(
            SupabaseChatRepository(self.client), client=self.client,
            generator=FakeGenerator(), retriever=FakeRetriever(),
        )
        with patch("app.domains.chat.service.collect_context", return_value={
            "facts": {"week": 18}, "guides": {"meal": [], "household": [], "health": [], "sleep": []},
        }):
            reply = await service.send_message(
                USER_ID, TARGET_DATE, ChatMessageInput(content="새 질문")
            )
        self.assertEqual(reply.content, "실제 생성된 답변")
        self.assertEqual(reply.routine_item_id, None)
        self.assertEqual(self.client.rows[-2]["content"], "새 질문")
        self.assertEqual(self.client.rows[-1]["content"], "실제 생성된 답변")
