import asyncio
import logging
from datetime import date
from typing import Awaitable, Callable, Protocol

from supabase import Client

from app.domains.care.schemas import ConditionInput
from app.domains.care.service import CareServicePort
from app.domains.errors import DomainConflictError, DomainNotFoundError, DomainStorageError
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.retriever import KnowledgeRetriever

from . import meal_memory
from .context import collect_context
from .repository import ChatRepository
from .responder import MEAL_REPLY_SCHEMA, REPLY_SCHEMA, generate_reply
from .schemas import (
    ChatMessageInput,
    ChatMessageResponse,
    MealAlternativeInput,
    MealAlternativeResponse,
    RoutineUpdateDecision,
    RoutineUpdateState,
    RoutineUpdateStatus,
)
from .supabase_repository import SupabaseChatRepository

# 09-22 식사 가이드 '다른 메뉴 보기': 챗봇 S5 식사 메모리를 그대로 쓰고, 카드는 반드시 1장.
ALTERNATIVE_RULE = "- 이번 요청은 식사 가이드의 '다른 메뉴 보기' 버튼이다. recommendation은 반드시 1개 채운다. content는 한 문장."
ALTERNATIVE_FAILED = "다른 메뉴를 찾지 못했어요. 잠시 후 다시 시도해 주세요."
CONDITION_UPDATE_RULE = (
    "오늘 컨디션 수정은 점수가 명확한 경우에만 condition_update로 제안한다. "
    "아직 저장하거나 루틴을 바꿨다고 말하지 않는다. 값이 모호하면 1~5 중 값을 다시 묻는다."
)
ROUTINE_UPDATE_FAILED = "컨디션은 저장됐지만 루틴 수정에 실패했어요. 다시 시도해 주세요."
CONDITION_UPDATE_FAILED = "컨디션을 수정하지 못했어요. 잠시 후 다시 시도해 주세요."
CONDITION_SCORE_FIELDS = (
    "nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue", "mood"
)
logger = logging.getLogger(__name__)


class ChatServicePort(Protocol):
    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]: ...

    async def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse: ...

    async def meal_alternative(
        self, user_id: str, target_date: date, payload: MealAlternativeInput
    ) -> MealAlternativeResponse: ...

    def get_routine_update(
        self, user_id: str, target_date: date, message_id: str
    ) -> RoutineUpdateState: ...

    def decide_routine_update(
        self, user_id: str, target_date: date, message_id: str, action: RoutineUpdateDecision
    ) -> tuple[RoutineUpdateState, bool]: ...

    async def run_routine_update(
        self, user_id: str, target_date: date, message_id: str,
        care: CareServicePort, regenerate: Callable[[], Awaitable[dict]],
    ) -> None: ...


class ChatService(ChatServicePort):
    def __init__(
        self, repository: ChatRepository, *, client: Client | None = None,
        generator: OpenAIRoutineGenerator | None = None,
        retriever: KnowledgeRetriever | None = None,
    ) -> None:
        self.repository = repository
        self.client = client
        self.generator = generator
        self.retriever = retriever

    def list_messages(self, user_id: str, target_date: date) -> list[ChatMessageResponse]:
        return self.repository.list_messages(user_id, target_date)

    async def meal_alternative(
        self, user_id: str, target_date: date, payload: MealAlternativeInput
    ) -> MealAlternativeResponse:
        """대화로 저장하지 않는 추천 1회. 거절한 메뉴는 프론트가 먼저 Care API(meal_reject)로 기록하므로
        식사 메모리 3(과거 메뉴 선택)에 들어가 다시 추천되지 않는다. 테이블에 쓰지 않는다."""
        if self.client is None or self.generator is None or self.retriever is None:
            raise DomainStorageError(ALTERNATIVE_FAILED)
        repository = self.repository
        if not isinstance(repository, SupabaseChatRepository):
            raise TypeError("meal alternative requires the Supabase chat repository")
        item_id = payload.routine_item_id
        if not await asyncio.to_thread(repository.validate_meal_item, user_id, target_date, item_id):
            raise DomainNotFoundError("해당 날짜의 식사 루틴을 찾을 수 없습니다.")
        context = await asyncio.to_thread(collect_context, self.client, user_id, target_date)
        memory = await asyncio.to_thread(meal_memory.load, self.client, user_id, target_date, item_id, context["facts"])
        reply = await generate_reply(
            self.generator, self.retriever, context, payload.request, [],
            memory["rules"] + "\n" + ALTERNATIVE_RULE, MEAL_REPLY_SCHEMA,
        )
        card = reply.recommendation
        if not card or meal_memory.is_banned(card, memory["banned"]):
            raise DomainStorageError(ALTERNATIVE_FAILED)  # AI 실패·카드 없음·금지 재료 → 503, 프론트는 지금 메뉴 유지
        return MealAlternativeResponse(routine_item_id=item_id, **card)

    async def send_message(
        self, user_id: str, target_date: date, payload: ChatMessageInput
    ) -> ChatMessageResponse:
        if self.client is None or self.generator is None or self.retriever is None:
            return self.repository.add_message(user_id, target_date, payload)
        repository = self.repository
        if not isinstance(repository, SupabaseChatRepository):
            raise TypeError("AI chat requires the Supabase chat repository")
        if payload.routine_item_id and not await asyncio.to_thread(
            repository.validate_meal_item, user_id, target_date, payload.routine_item_id
        ):
            raise DomainNotFoundError("해당 날짜의 식사 루틴을 찾을 수 없습니다.")
        context = await asyncio.to_thread(collect_context, self.client, user_id, target_date)
        # 09-22 결정: LLM 이력은 같은 날짜 대화 전체(모드 무관, 최근 20개). 화면 목록은 프론트가 모드별로 거른다.
        history = await asyncio.to_thread(repository.history_for_day, user_id, target_date)
        schema, banned = REPLY_SCHEMA, []
        if payload.routine_item_id:  # S5 식사 모드: 식사 메모리 + 추천 카드
            memory = await asyncio.to_thread(
                meal_memory.load, self.client, user_id, target_date, payload.routine_item_id, context["facts"]
            )
            rules = memory["rules"] + "\n" + CONDITION_UPDATE_RULE
            schema, banned = MEAL_REPLY_SCHEMA, memory["banned"]
        else:
            rules = (
                "일반 상담이다. 식사 메뉴 변경 요청은 식사 가이드에서 할 수 있다고 안내한다. "
                "가사·건강·수면 루틴 직접 변경 요청은 지원하지 않는다고 안내한다.\n"
                + CONDITION_UPDATE_RULE
            )
        reply = await generate_reply(
            self.generator, self.retriever, context, payload.content, history, rules, schema
        )
        content, actions, card = reply.content, reply.suggested_actions, reply.recommendation
        if reply.condition_update:
            # 컨디션 확인과 메뉴 추천을 한 응답에 섞지 않는다. 확인 버튼은 routine_update 전용 UI가 그린다.
            actions, card = [], None
        elif card and meal_memory.is_banned(card, banned):
            # 카드만 버리면 답변 문장에 금지 메뉴 이름이 남을 수 있어 문장도 고정 문구로 바꾼다. 재시도는 10초 제한 때문에 안 한다.
            content, actions, card = meal_memory.BANNED_REPLY, [], None
        elif card:
            actions = meal_memory.CARD_ACTIONS
        return await asyncio.to_thread(
            repository.add_ai_message, user_id, target_date, payload, content, actions, card,
            reply.condition_update,
        )

    def get_routine_update(
        self, user_id: str, target_date: date, message_id: str
    ) -> RoutineUpdateState:
        return self.repository.get_routine_update(user_id, target_date, message_id)

    def decide_routine_update(
        self, user_id: str, target_date: date, message_id: str, action: RoutineUpdateDecision
    ) -> tuple[RoutineUpdateState, bool]:
        current = self.repository.get_routine_update(user_id, target_date, message_id)
        if action == RoutineUpdateDecision.CANCEL:
            if current.status != RoutineUpdateStatus.AWAITING_CONFIRMATION:
                raise DomainConflictError("대기 중인 컨디션 수정만 취소할 수 있습니다.")
            return self.repository.set_routine_update_status(
                user_id, target_date, message_id, RoutineUpdateStatus.CANCELLED
            ), False
        if current.status in (RoutineUpdateStatus.QUEUED, RoutineUpdateStatus.RUNNING):
            return current, False
        if current.status == RoutineUpdateStatus.SUCCEEDED:
            return current, False
        if current.status == RoutineUpdateStatus.CANCELLED:
            raise DomainConflictError("취소한 컨디션 수정은 다시 실행할 수 없습니다.")
        queued = self.repository.set_routine_update_status(
            user_id, target_date, message_id, RoutineUpdateStatus.QUEUED
        )
        return queued, True

    async def run_routine_update(
        self, user_id: str, target_date: date, message_id: str,
        care: CareServicePort, regenerate: Callable[[], Awaitable[dict]],
    ) -> None:
        """응답 반환 뒤 실행된다. 채팅 저장·조회와 별도 상태라 대화를 막지 않는다."""
        condition_saved = False
        try:
            state = await asyncio.to_thread(
                self.repository.set_routine_update_status,
                user_id, target_date, message_id, RoutineUpdateStatus.RUNNING,
            )
            current = await asyncio.to_thread(care.get_condition, user_id, target_date)
            values = {field: getattr(current, field) for field in CONDITION_SCORE_FIELDS}
            for change in state.changes:
                values[change.field.value] = change.value
            await asyncio.to_thread(
                care.save_condition, user_id, target_date, ConditionInput(**values)
            )
            condition_saved = True
            saved = await regenerate()
            if saved.get("source") != "ai" and not saved.get("unchanged"):
                raise RuntimeError("AI 루틴 재생성 실패")
            await asyncio.to_thread(
                self.repository.set_routine_update_status,
                user_id, target_date, message_id, RoutineUpdateStatus.SUCCEEDED,
                routine_revision=int(saved.get("revision") or 1),
            )
        except Exception:
            logger.exception("챗봇 컨디션 수정 후 루틴 재생성 실패")
            try:
                await asyncio.to_thread(
                    self.repository.set_routine_update_status,
                    user_id, target_date, message_id, RoutineUpdateStatus.FAILED,
                    error_message=(
                        ROUTINE_UPDATE_FAILED if condition_saved else CONDITION_UPDATE_FAILED
                    ),
                )
            except Exception:
                logger.exception("챗봇 루틴 재생성 실패 상태 저장도 실패")
