"""챗봇 S1: 두 모드(일반·식사)가 같이 쓰는 공통 컨텍스트. 설계: docs/chatbot/chatbot_guide.md S1.

웬즈데이 AI의 입력 수집(inputs.collect_facts)을 재사용한다. 질문별 RAG는 S2에서 KnowledgeRetriever.search를 바로 쓴다.
기분(mood)은 09-22 회의 결정으로 넣지 않는다(collect_facts가 이미 읽지 않음).
"""

from __future__ import annotations

from datetime import date
from typing import Any

from supabase import Client

from app.services.routine.inputs import collect_facts

# NFR-014: LLM에 넘기는 키. 웬즈데이 LLM_FACT_KEYS에서 챗봇에 필요 없는 예정 활동·전일 요약만 뺐다.
FACT_KEYS = (
    "week", "is_first_pregnancy", "is_multiple_pregnancy", "allergies", "medical_conditions", "medical_note",
    "nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue",
)
GUIDE_CATEGORIES = ("meal", "household", "health", "sleep")
_PAIN_LABELS = {"waist_pain": "허리", "pelvis_pain": "골반", "leg_pain": "다리", "wrist_pain": "손목"}
SEVERE = 4  # 컨디션 1~5 중 이 이상만 배너에 올린다


def collect_context(client: Client, user_id: str, today: date) -> dict[str, Any]:
    """{facts, guides}. 컨디션이 없으면 facts의 컨디션 값은 None. 프로필이 없으면 ProfileMissingError."""
    facts = collect_facts(client, user_id, today, require_condition=False)
    return {"facts": {key: facts.get(key) for key in FACT_KEYS}, "guides": today_guides(client, user_id, today)}


def today_guides(client: Client, user_id: str, today: date) -> dict[str, list[str]]:
    """오늘 4종 가이드 항목 제목. 루틴이 없으면 빈 목록. 재생성으로 빠진 행(removed)은 제외."""
    rows = (
        client.table("routine_items")
        .select("category", "title", "change_kind")
        .eq("user_id", user_id)
        .eq("date", today.isoformat())
        .order("sort_order")
        .execute()
        .data
    )
    guides: dict[str, list[str]] = {category: [] for category in GUIDE_CATEGORIES}
    for row in rows:
        # .neq()는 NULL 행까지 걸러서 Python에서 비교한다(guide/query_service.py와 같은 이유).
        if row.get("change_kind") != "removed" and row["category"] in guides:
            guides[row["category"]].append(row["title"])
    return guides


def banner_text(facts: dict[str, Any]) -> str:
    """상단 배너 한 줄. 예: "임신 18주차 · 입덧 심함 · 허리 통증 · 갑각류 알레르기"."""
    parts = [f"임신 {facts['week']}주차"]
    if (facts.get("nausea") or 0) >= SEVERE:
        parts.append("입덧 심함")
    parts += [f"{label} 통증" for key, label in _PAIN_LABELS.items() if (facts.get(key) or 0) >= SEVERE]
    if (facts.get("fatigue") or 0) >= SEVERE:
        parts.append("피로 심함")
    parts += list(facts.get("medical_conditions") or [])
    parts += [f"{allergy} 알레르기" for allergy in facts.get("allergies") or []]
    return " · ".join(parts)

