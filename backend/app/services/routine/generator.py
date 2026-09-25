"""파이프라인 B ⑤: OpenAI 호출 + JSON 스키마 강제. ⑥ 검증·폴백은 이 결과를 받아 처리한다."""

from __future__ import annotations

import asyncio
import json
from typing import Any

from openai import AsyncOpenAI

from app.core.config import Settings
from app.services.llm_service import LLMService
from app.services.routine.prompt import (
    CATEGORIES,
    EDIT_SYSTEM_PROMPT,
    ROUTINE_SCHEMA,
    SYSTEM_PROMPT,
    TIP_REQUEST,
    TIP_SCHEMA,
    WEEK_GUIDE_SCHEMA,
    WEEK_GUIDE_SYSTEM_PROMPT,
    build_edit_prompt,
    build_user_prompt,
    build_week_guide_prompt,
    category_schema,
)

# NFR-001 p95 10초. 임베딩(③)에도 시간이 들어 LLM 호출은 8초로 잡는다.
LLM_TIMEOUT_SEC = 8.0


class OpenAIRoutineGenerator(LLMService):
    def __init__(self, settings: Settings, client: AsyncOpenAI | None = None) -> None:
        super().__init__(settings)
        self.client = client or AsyncOpenAI(
            api_key=settings.llm_api_key.get_secret_value(),
            base_url=settings.llm_api_base_url or None,
            timeout=LLM_TIMEOUT_SEC,
            max_retries=0,  # 재시도하면 10초를 넘기므로 실패 즉시 폴백(⑥)으로 넘긴다.
        )
        self.model = settings.llm_model

    async def generate(
        self, prompt: str, schema: dict[str, Any] = ROUTINE_SCHEMA, name: str = "daily_routine",
        system: str = SYSTEM_PROMPT,
    ) -> str:
        """LLMService 계약: 프롬프트 → 스키마를 만족하는 JSON 문자열."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {"name": name, "schema": schema, "strict": True},
            },
        )
        return response.choices[0].message.content or ""

    async def generate_category(
        self,
        category: str,
        facts: dict[str, Any],
        constraints: dict[str, list[dict[str, Any]]] | None = None,
        chunks: list[dict[str, Any]] | None = None,
    ) -> Any:
        """카테고리 1개 생성. 그 카테고리의 규칙·참고 문단만 넣어 입력과 출력 길이를 줄인다."""
        own = {k: [c for c in v if c.get("category") == category] for k, v in (constraints or {}).items()}
        prompt = build_user_prompt(facts, own, chunks, category)
        return json.loads(await self.generate(prompt, category_schema(category), f"routine_{category}"))[category]

    async def generate_edit(
        self,
        category: str,
        facts: dict[str, Any],
        decision: dict[str, Any],
        changes: list[dict[str, Any]],
        contributors: list[dict[str, Any]],
        previous: Any,
        constraints: dict[str, list[dict[str, Any]]] | None = None,
        chunks: list[dict[str, Any]] | None = None,
    ) -> Any:
        """S10: 컨디션 수정 시 가이드 1개 조정. 출력 스키마는 최초 생성과 같다."""
        own = {k: [c for c in v if c.get("category") == category] for k, v in (constraints or {}).items()}
        prompt = build_edit_prompt(category, facts, decision, changes, contributors, previous, own, chunks)
        content = await self.generate(prompt, category_schema(category), f"routine_edit_{category}", EDIT_SYSTEM_PROMPT)
        return json.loads(content)[category]

    async def generate_tip(
        self,
        facts: dict[str, Any],
        constraints: dict[str, list[dict[str, Any]]] | None = None,
        chunks: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        """S7: 웰컴 카드 팁 1개 {text, source_ids}. 실패는 예외로 올리고, 루틴 폴백 여부는 service가 분리해 판단한다."""
        prompt = build_user_prompt(facts, constraints, chunks, request=TIP_REQUEST)
        return json.loads(await self.generate(prompt, TIP_SCHEMA, "routine_tip"))["tip"]

    async def generate_week_guide(
        self, week: int, chunks: list[dict[str, Any]]
    ) -> dict[str, Any]:
        """홈 주차 안내 1건. 제공된 RAG 문단 밖의 내용은 프롬프트와 후단 검증으로 막는다."""
        prompt = build_week_guide_prompt(week, chunks)
        content = await self.generate(
            prompt,
            WEEK_GUIDE_SCHEMA,
            "home_week_guide",
            WEEK_GUIDE_SYSTEM_PROMPT,
        )
        return json.loads(content)

    async def generate_routine(
        self,
        facts: dict[str, Any],
        constraints: dict[str, list[dict[str, Any]]] | None = None,
        chunks_by_category: dict[str, list[dict[str, Any]]] | None = None,
    ) -> dict[str, Any]:
        """①②③ → 4종 루틴 dict. 카테고리 4개를 동시에 호출한다(한 번에 쓰면 출력이 길어 8초를 넘김).

        하나라도 실패(타임아웃·API 오류·JSON 오류)하면 예외를 올려 ⑥이 4종 전체를 폴백한다.
        """
        # ponytail: 한 카테고리 실패도 전체 폴백. 부분 폴백은 daily_routines.source 의미(폴백률 측정)가 바뀌어 보류.
        chunks_by_category = chunks_by_category or {}
        results = await asyncio.gather(
            *(self.generate_category(c, facts, constraints, chunks_by_category.get(c)) for c in CATEGORIES)
        )
        return dict(zip(CATEGORIES, results))
