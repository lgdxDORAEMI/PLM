"""챗봇 S2: 공통 컨텍스트(S1) + 최근 대화 + 질문 → OpenAI → 검증. 실패하면 고정 문구(FUC-W-CALLBACK-001 ②).

LLM 호출은 웬즈데이 OpenAIRoutineGenerator.generate(스키마 강제·8초·재시도 없음)를 그대로 쓴다.
모드별 지시(일반 모드 변경 요청 안내 S3, 식사 메모리·추천 카드 S5)는 `extra_rules`로 덧붙인다.
설계: docs/chatbot/chatbot_guide.md S2.
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Any

from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.retriever import KnowledgeRetriever

logger = logging.getLogger(__name__)

TOTAL_TIMEOUT_SEC = 9.5  # NFR-001 10초. 임베딩 + LLM(8초) 합계 상한
HISTORY_LIMIT = 6
MAX_ACTIONS = 2
FALLBACK_REPLY = "지금은 답변을 만들 수 없어요. 잠시 후 다시 물어봐 주세요."

REPLY_SCHEMA = {
    "type": "object",
    "properties": {
        "content": {"type": "string"},
        "suggested_actions": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["content", "suggested_actions"],
    "additionalProperties": False,
}

SYSTEM_PROMPT = """너는 임산부 생활관리 앱의 챗봇이다. 한국어로 3~4문장 이내, 부드러운 존댓말로 답한다.
규칙:
1. 답은 반드시 [사용자 정보]의 임신 주차·진단·알레르기·오늘 컨디션을 기준으로 한다. 사용자에게 다시 묻지 않는다.
2. 컨디션 값이 null이면 오늘 컨디션을 모르는 것이다. 주차·프로필만으로 답한다.
3. 의료 진단·약 처방을 하지 않는다. 출혈·심한 복통·태동 감소·양수 등 위험 신호가 있으면 "지금 바로 병원에 문의해 주세요"를 먼저 말한다.
4. [참고 자료]에 근거가 없는 수치·효능은 지어내지 않는다.
5. 루틴을 바꿨다고 말하지 않는다. 챗봇은 루틴을 바꾸지 않는다.
6. suggested_actions는 다음 행동 버튼 문구다. 필요할 때만 최대 2개, 각 12자 이내. 없으면 빈 배열."""


@dataclass
class ChatReply:
    content: str
    suggested_actions: list[str] = field(default_factory=list)
    source: str = "ai"  # ai | fallback


def build_prompt(
    context: dict[str, Any], question: str, history: list[dict[str, str]], chunks: list[dict[str, Any]],
    extra_rules: str = "",
) -> str:
    sections = [
        "[사용자 정보]\n" + json.dumps(context["facts"], ensure_ascii=False),
        "[오늘 4종 가이드]\n" + json.dumps(context["guides"], ensure_ascii=False),
        "[참고 자료]\n" + ("\n".join(f"- {c['content']}" for c in chunks) or "없음"),
        "[최근 대화]\n" + ("\n".join(f"{m['role']}: {m['content']}" for m in history[-HISTORY_LIMIT:]) or "없음"),
    ]
    if extra_rules:
        sections.append("[이 대화 추가 규칙]\n" + extra_rules)
    sections.append("[질문]\n" + question)
    return "\n\n".join(sections)


async def generate_reply(
    generator: OpenAIRoutineGenerator,
    retriever: KnowledgeRetriever,
    context: dict[str, Any],
    question: str,
    history: list[dict[str, str]],
    extra_rules: str = "",
) -> ChatReply:
    """예외를 올리지 않는다. 타임아웃·API 오류·스키마 불일치·빈 답은 모두 FALLBACK_REPLY."""
    try:
        return await asyncio.wait_for(
            _generate(generator, retriever, context, question, history, extra_rules), TOTAL_TIMEOUT_SEC
        )
    except Exception:
        logger.exception("챗봇 응답 생성 실패 — 고정 문구로 대체")
        return ChatReply(FALLBACK_REPLY, [], "fallback")


async def _generate(generator, retriever, context, question, history, extra_rules) -> ChatReply:
    try:
        chunks = await retriever.search(question, context["facts"].get("week"))
    except Exception:
        # 참고 자료 없이도 답은 할 수 있다. 검색 실패만으로 폴백하지 않는다.
        logger.exception("챗봇 RAG 검색 실패 — 참고 자료 없이 진행")
        chunks = []
    prompt = build_prompt(context, question, history, chunks, extra_rules)
    data = json.loads(await generator.generate(prompt, REPLY_SCHEMA, "chat_reply", SYSTEM_PROMPT))
    content = data["content"].strip()
    if not content:
        raise ValueError("빈 답변")
    actions = [a.strip() for a in data["suggested_actions"] if a.strip()][:MAX_ACTIONS]
    return ChatReply(content, actions, "ai")
