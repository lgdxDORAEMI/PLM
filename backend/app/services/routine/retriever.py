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

    def _match(self, embedding: list[float], week: int | None, category: str | None) -> list[dict[str, Any]]:
        return self.supabase.rpc(
            "match_pregnancy_knowledge",
            {
                "query_embedding": embedding,
                "match_count": MATCH_COUNT,
                "filter_week": week,
                "filter_category": CATEGORY_FILTERS[category] if category else None,
            },
        ).execute().data

    async def search(self, text: str, week: int | None) -> list[dict[str, Any]]:
        """챗봇: 질문 1개 → 카테고리 필터 없이 상위 MATCH_COUNT개. chunk 모양은 retrieve와 같다."""
        [embedding] = await self.embed([text])
        return await asyncio.to_thread(self._match, embedding, week, None)

    async def search_week_guide(self, week: int) -> list[dict[str, Any]]:
        """홈 주차 안내: 주차에 맞는 신체 변화·생활 주의 근거를 카테고리 제한 없이 찾는다."""
        search_week = min(40, max(1, week))
        return await self.search(
            f"임신 {search_week}주에 나타날 수 있는 일반적인 신체 변화와 일상생활 주의사항",
            search_week,
        )

    async def retrieve(
        self, facts: dict[str, Any], categories: list[str] | None = None
    ) -> dict[str, list[dict[str, Any]]]:
        """{category: [chunk...]}. chunk = {id, category, week_start, week_end, content, source, similarity}.

        임베딩은 질의를 1회 호출로 묶는다(NFR-001). categories를 주면 그 카테고리만 검색한다(S10 수정 경로).
        """
        queries = build_queries(facts)
        if categories is not None:
            queries = {c: q for c, q in queries.items() if c in categories}
        categories = list(queries)
        embeddings = await self.embed([queries[c] for c in categories])
        week = facts.get("week")
        # 09-22: 4회 RPC를 스레드 4개로 동시에 돌리면 supabase-py의 HTTP/2 연결 1개를 여러 스레드가 함께 써서
        # Windows에서 ReadError [WinError 10035]로 루틴이 폴백됐다. 스레드 1개에서 차례로 실행한다(약 +0.3초 추정).
        # ponytail: 순차 실행. 더 빨라야 하면 스레드마다 별도 클라이언트 또는 비동기 클라이언트로 교체.
        def match_all() -> list[list[dict[str, Any]]]:
            return [self._match(emb, week, cat) for cat, emb in zip(categories, embeddings)]

        return dict(zip(categories, await asyncio.to_thread(match_all)))
