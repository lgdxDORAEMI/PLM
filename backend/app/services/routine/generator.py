"""파이프라인 B ⑤: OpenAI 호출 + JSON 스키마 강제. ⑥ 검증·폴백은 이 결과를 받아 처리한다."""

from __future__ import annotations

import json
from typing import Any

from openai import AsyncOpenAI

from app.core.config import Settings
from app.services.llm_service import LLMService
from app.services.routine.prompt import ROUTINE_SCHEMA, SYSTEM_PROMPT, build_user_prompt

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

    async def generate(self, prompt: str) -> str:
        """LLMService 계약: 프롬프트 → 스키마를 만족하는 JSON 문자열."""
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            response_format={
                "type": "json_schema",
                "json_schema": {"name": "daily_routine", "schema": ROUTINE_SCHEMA, "strict": True},
            },
        )
        return response.choices[0].message.content or ""

    async def generate_routine(
        self,
        facts: dict[str, Any],
        constraints: dict[str, list[dict[str, str]]] | None = None,
        chunks: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        """①②③ → 4종 루틴 dict. 실패(타임아웃·API 오류·JSON 오류)는 예외로 올려 ⑥이 폴백한다."""
        return json.loads(await self.generate(build_user_prompt(facts, constraints, chunks)))
