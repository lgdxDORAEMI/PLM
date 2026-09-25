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

from .schemas import ConditionChange

logger = logging.getLogger(__name__)

TOTAL_TIMEOUT_SEC = 9.5  # NFR-001 10초. 임베딩 + LLM(8초) 합계 상한
HISTORY_LIMIT = 20  # 09-22 결정: 같은 날짜 대화 전체(모드 무관)에서 최근 20개
MAX_ACTIONS = 2
FALLBACK_REPLY = "지금은 답변을 만들 수 없어요. 잠시 후 다시 물어봐 주세요."

CONDITION_FIELDS = ["nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue"]
CONDITION_LABELS = {
    "nausea": "입덧",
    "waist_pain": "허리 통증",
    "pelvis_pain": "골반 통증",
    "leg_pain": "다리 통증",
    "wrist_pain": "손목 통증",
    "fatigue": "피로도",
}
CONDITION_UPDATE_SCHEMA = {
    "anyOf": [
        {
            "type": "object",
            "properties": {
                "changes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "field": {"type": "string", "enum": CONDITION_FIELDS},
                            "value": {"type": "integer", "minimum": 1, "maximum": 5},
                        },
                        "required": ["field", "value"],
                        "additionalProperties": False,
                    },
                },
            },
            "required": ["changes"],
            "additionalProperties": False,
        },
        {"type": "null"},
    ]
}

REPLY_SCHEMA = {
    "type": "object",
    "properties": {
        "content": {"type": "string"},
        "suggested_actions": {"type": "array", "items": {"type": "string"}},
        "condition_update": CONDITION_UPDATE_SCHEMA,
    },
    "required": ["content", "suggested_actions", "condition_update"],
    "additionalProperties": False,
}

# S5 식사 모드: 추천 카드 1장(없으면 null). 모양 = 웬즈데이 meal payload(prompt._MEAL_ITEM)와 같게.
_STR = {"type": "string"}
RECOMMENDATION_SCHEMA = {
    "type": "object",
    "properties": {
        "title": _STR,
        "reason": _STR,
        "nutritionTags": {"type": "array", "items": _STR},
        "cautions": {"type": "array", "items": {
            "type": "object",
            "properties": {"title": _STR, "description": _STR, "badge": _STR},
            "required": ["title", "description", "badge"],
            "additionalProperties": False,
        }},
    },
    "required": ["title", "reason", "nutritionTags", "cautions"],
    "additionalProperties": False,
}
MEAL_REPLY_SCHEMA = {
    **REPLY_SCHEMA,
    "properties": {**REPLY_SCHEMA["properties"], "recommendation": {"anyOf": [RECOMMENDATION_SCHEMA, {"type": "null"}]}},
    "required": [*REPLY_SCHEMA["required"], "recommendation"],
}

SYSTEM_PROMPT = """너는 임산부 생활관리 앱의 챗봇이다. 한국어로 3~4문장 이내, 부드러운 존댓말로 답한다.
규칙:
1. 답은 반드시 [사용자 정보]의 임신 주차·진단·알레르기·오늘 컨디션을 기준으로 한다. 사용자에게 다시 묻지 않는다.
2. 컨디션 값이 null이면 오늘 컨디션을 모르는 것이다. 주차·프로필만으로 답한다.
3. 의료 진단·약 처방을 하지 않는다. 출혈·심한 복통·태동 감소·양수 등 위험 신호가 있으면 "지금 바로 병원에 문의해 주세요"를 먼저 말한다.
4. [참고 자료]에 근거가 없는 수치·효능은 지어내지 않는다.
5. 사용자가 오늘 컨디션 점수를 명확히 1~5로 수정해 달라고 하면 condition_update에 변경 필드와 값을 넣고, content로 변경 내용을 확인한다. 아직 바꿨다고 말하지 않는다.
6. 수정 의도는 있지만 1~5 값이 불명확하면 임의로 점수화하지 말고 content로 값을 다시 묻고 condition_update는 null로 둔다.
7. condition_update 대상은 nausea, waist_pain, pelvis_pain, leg_pain, wrist_pain, fatigue뿐이다. mood는 읽거나 수정하지 않는다.
8. suggested_actions는 다음 행동 버튼 문구다. 필요할 때만 최대 2개, 각 12자 이내. 없으면 빈 배열.
9. [최근 대화]에 [컨디션 수정 상태]가 있으면 그 상태를 사실대로 안내한다. 사용자 확인 대기는 아직 저장·재생성을 시작하지 않은 상태이므로 화면의 '반영하기'를 누르라고 안내한다. 대기·실행 중이면 대화는 계속할 수 있다고 말하고, 완료·실패·취소 상태도 그대로 설명한다. 단순 상태 질문에는 새 condition_update를 만들지 않는다."""


@dataclass
class ChatReply:
    content: str
    suggested_actions: list[str] = field(default_factory=list)
    source: str = "ai"  # ai | fallback
    recommendation: dict[str, Any] | None = None  # S5 식사 모드만
    condition_update: dict[str, Any] | None = None  # S8 명시적 1~5 컨디션 수정 후보


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
    schema: dict[str, Any] = REPLY_SCHEMA,
) -> ChatReply:
    """예외를 올리지 않는다. 타임아웃·API 오류·스키마 불일치·빈 답은 모두 FALLBACK_REPLY."""
    try:
        return await asyncio.wait_for(
            _generate(generator, retriever, context, question, history, extra_rules, schema), TOTAL_TIMEOUT_SEC
        )
    except Exception:
        logger.exception("챗봇 응답 생성 실패 — 고정 문구로 대체")
        return ChatReply(FALLBACK_REPLY, [], "fallback")


async def _generate(generator, retriever, context, question, history, extra_rules, schema) -> ChatReply:
    try:
        chunks = await retriever.search(question, context["facts"].get("week"))
    except Exception:
        # 참고 자료 없이도 답은 할 수 있다. 검색 실패만으로 폴백하지 않는다.
        logger.exception("챗봇 RAG 검색 실패 — 참고 자료 없이 진행")
        chunks = []
    prompt = build_prompt(context, question, history, chunks, extra_rules)
    data = json.loads(await generator.generate(prompt, schema, "chat_reply", SYSTEM_PROMPT))
    content = data["content"].strip()
    if not content:
        raise ValueError("빈 답변")
    actions = [a.strip() for a in data["suggested_actions"] if a.strip()][:MAX_ACTIONS]
    update = data.get("condition_update")
    if update is not None:
        deduped: dict[str, dict[str, Any]] = {}
        for raw in update["changes"]:
            change = ConditionChange.model_validate(raw)
            deduped[change.field.value] = change.model_dump(mode="json")
        if not deduped:
            update = None
        else:
            changes = list(deduped.values())
            summary = " · ".join(
                f"{CONDITION_LABELS[change['field']]} {change['value']}단계"
                for change in changes
            )
            update = {
                "summary": f"{summary}로 수정하고 오늘 루틴을 다시 맞춥니다.",
                "changes": changes,
            }
    return ChatReply(content, actions, "ai", data.get("recommendation"), update)
