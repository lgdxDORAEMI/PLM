"""파이프라인 B ③: RAG 검색. 컨디션 문장 → OpenAI 임베딩 → RPC match_pregnancy_knowledge.

임베딩 모델은 적재(tools/rag_ingest/02_translate_chunk_embed_upload.py)와 반드시 같아야 한다.
"""

from __future__ import annotations

import asyncio
from typing import Any

from openai import AsyncOpenAI
from supabase import Client

# 적재 스크립트 --embedding-model 기본값. 바꾸면 pregnancy_knowledge 전체 재적재 필요.
EMBEDDING_MODEL = "text-embedding-3-small"
MATCH_COUNT = 5

# pregnancy_knowledge.category는 "식사·영양 · 활동·운동 · 안전" 같은 문자열. RPC 필터는 ilike 부분일치.
CATEGORY_FILTERS = {"meal": "식사·영양", "household": "활동·운동", "health": "통증", "sleep": "수면"}

_PAIN_LABELS = {"waist_pain": "허리", "pelvis_pain": "골반", "leg_pain": "다리", "wrist_pain": "손목"}


def build_queries(facts: dict[str, Any]) -> dict[str, str]:
    """카테고리별 검색 질의 문장. 오늘 컨디션을 자연어로 풀어 청크와 뜻이 가깝게 만든다."""
    week = facts.get("week")
    pains = sorted(
        ((facts.get(k) or 0), label) for k, label in _PAIN_LABELS.items()
    )
    top_pain = pains[-1][1] if pains and pains[-1][0] >= 3 else "특별한 통증 없음"
    nausea = "입덧이 심한" if (facts.get("nausea") or 0) >= 4 else "입덧이 가벼운"
    fatigue = "피로가 심한" if (facts.get("fatigue") or 0) >= 4 else ""
    conditions = ", ".join(facts.get("medical_conditions") or []) or "특이 진단 없음"
    return {
        "meal": f"임신 {week}주 {nausea} 임산부의 식사와 영양, 주의 식품. 진단: {conditions}",
        "household": f"임신 {week}주 임산부가 피해야 할 집안일과 활동, {top_pain} 통증이 있을 때 안전한 활동",
        "health": f"임신 {week}주 {top_pain} 통증 완화 스트레칭과 운동, {fatigue} 임산부 활동 강도",
        "sleep": f"임신 {week}주 임산부의 수면 자세와 수면 환경, 불면과 피로",
    }


class KnowledgeRetriever:
    def __init__(self, supabase: Client, openai: AsyncOpenAI) -> None:
        self.supabase = supabase
        self.openai = openai

    async def embed(self, texts: list[str]) -> list[list[float]]:
        response = await self.openai.embeddings.create(model=EMBEDDING_MODEL, input=texts)
        return [item.embedding for item in response.data]

    def _match(self, embedding: list[float], week: int | None, category: str) -> list[dict[str, Any]]:
        return self.supabase.rpc(
            "match_pregnancy_knowledge",
            {
                "query_embedding": embedding,
                "match_count": MATCH_COUNT,
                "filter_week": week,
                "filter_category": CATEGORY_FILTERS[category],
            },
        ).execute().data

    async def retrieve(self, facts: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
        """{category: [chunk...]}. chunk = {id, category, week_start, week_end, content, source, similarity}.

        임베딩은 4개 질의를 1회 호출로 묶는다(NFR-001).
        """
        queries = build_queries(facts)
        categories = list(queries)
        embeddings = await self.embed([queries[c] for c in categories])
        week = facts.get("week")
        # ponytail: supabase-py는 동기 클라이언트. 4회 RPC를 스레드에서 병렬 실행. 비동기 클라이언트 필요해지면 교체.
        results = await asyncio.gather(
            *(asyncio.to_thread(self._match, emb, week, cat) for cat, emb in zip(categories, embeddings))
        )
        return dict(zip(categories, results))
