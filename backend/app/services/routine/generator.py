"""파이프라인 B ⑤: OpenAI 호출 + JSON 스키마 강제. ⑥ 검증·폴백은 이 결과를 받아 처리한다."""

from __future__ import annotations

import asyncio
import json
from typing import Any

from openai import AsyncOpenAI

from app.core.config import Settings
from app.services.llm_service import LLMService
from app.services.routine.prompt import CATEGORIES, ROUTINE_SCHEMA, SYSTEM_PROMPT, build_user_prompt, category_schema

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

    async def generate(self, prompt: str, schema: dict[str, Any] = ROUTINE_SCHEMA, name: str = "daily_routine") -> str:
        """LLMService 계약: 프롬프트 → 스키마를 만족하는 JSON 문자열."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
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
