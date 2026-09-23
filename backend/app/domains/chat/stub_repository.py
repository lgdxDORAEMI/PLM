from datetime import date, datetime, timezone
from uuid import uuid4

from .repository import ChatRepository
from .schemas import ChatMessageInput, ChatMessageResponse, ChatRole

# NFR-027(대화 이력 보관·파기 기준)이 아직 확정되지 않아 이 Stub은 프로세스 메모리에만
# 쌓는다. 실제 AI 응답 대신 계약을 만족하는 고정 안내 문구만 돌려준다 — 실제 답변이
# 있는 것처럼 조언·메뉴를 지어내지 않는다.
PLACEHOLDER_REPLY = "아직 실제 AI 응답 기능은 준비 중이에요. 곧 연결할게요."


class StubChatRepository(ChatRepository):
    """Chat 계약 검증용 메모리 Stub. 프로세스 재시작 시 데이터가 초기화된다."""

    def __init__(self) -> None:
        self._messages: dict[tuple[str, date], list[ChatMessageResponse]] = {}

    def list_messages(
        self, user_id: str, target_date: date | None
    ) -> list[ChatMessageResponse]:
        if target_date is not None:
            return list(self._messages.get((user_id, target_date), []))
        messages = [
            message
            for (owner_id, _), rows in self._messages.items()
            if owner_id == user_id
            for message in rows
        ]
        return sorted(messages, key=lambda message: message.created_at)

    def add_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse:
        history = self._messages.setdefault((user_id, target_date), [])
        history.append(
            ChatMessageResponse(
                message_id=str(uuid4()),
                role=ChatRole.USER,
                content=payload.content,
                created_at=datetime.now(timezone.utc),
            )
        )
        reply = ChatMessageResponse(
            message_id=str(uuid4()),
            role=ChatRole.ASSISTANT,
            content=PLACEHOLDER_REPLY,
            suggested_actions=None,
            created_at=datetime.now(timezone.utc),
        )
        history.append(reply)
        return reply
