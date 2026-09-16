"""파이프라인 B 조율: ① 입력 → ② 룰 → ③ RAG → ④⑤ 생성 → ⑥ 검증·폴백 → ⑦ 저장."""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import date
from pathlib import Path
from typing import Any

import yaml
from openai import AsyncOpenAI
from supabase import Client

from app.core.config import Settings
from app.services.routine import repository
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.inputs import collect_facts
from app.services.routine.prompt import PROMPT_VERSION
from app.services.routine.retriever import KnowledgeRetriever
from app.services.routine.rules import apply_rules

logger = logging.getLogger(__name__)

FALLBACK_PATH = Path(__file__).resolve().parent / "fallback.yaml"
# NFR-001 p95 10초. 임베딩+검색+생성 전체 상한. 넘으면 폴백.
TOTAL_TIMEOUT_SEC = 9.5

# NFR-014: 이 키만 LLM에 보낸다. 자유 텍스트 진료 메모(medical_note)는 W-PROFILE-006 요구대로 포함.
LLM_FACT_KEYS = (
    "week", "is_first_pregnancy", "is_multiple_pregnancy", "allergies", "medical_conditions", "medical_note",
    "nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue", "mood", "sleep_quality",
    "planned_activities",
)


def load_template() -> dict[str, Any]:
    return yaml.safe_load(FALLBACK_PATH.read_text(encoding="utf-8"))


def validate(
    routine: dict[str, Any],
    constraints: dict[str, list[dict[str, str]]],
    allowed_source_ids: set[int],
) -> dict[str, Any]:
    """⑥ 검증: exclude 대상이 남은 항목 제거, 없는 source_id 제거. 원본은 바꾸지 않는다."""
    # ponytail: target "ingredient:갑각류"의 값 부분을 항목 JSON에 부분일치. 코드형 target(activity:walk)은
    # 한국어 본문과 안 맞아 못 걸러낸다 → 필요해지면 rules.yaml에 keywords 필드 추가.
    banned = [c["target"].split(":", 1)[-1] for c in constraints.get("exclude", [])]

    def keep(entry: dict[str, Any]) -> bool:
        text = json.dumps(entry, ensure_ascii=False)
        return not any(word and word in text for word in banned)

    def clean(entry: dict[str, Any]) -> dict[str, Any]:
        ids = [int(i) for i in entry.get("source_ids") or [] if int(i) in allowed_source_ids]
        return {**entry, "source_ids": ids}

    result: dict[str, Any] = {}
    for category in ("meal", "household", "health"):
        result[category] = [clean(e) for e in routine.get(category) or [] if keep(e)]
    sleep = routine.get("sleep") or {}
    result["sleep"] = clean(sleep) if sleep else {}
    return result


class RoutineService:
    def __init__(self, supabase: Client, settings: Settings, openai: AsyncOpenAI | None = None) -> None:
        self.supabase = supabase
        self.settings = settings
        self.openai = openai or AsyncOpenAI(
            api_key=settings.llm_api_key.get_secret_value(),
            base_url=settings.llm_api_base_url or None,
            timeout=TOTAL_TIMEOUT_SEC,
            max_retries=0,
        )
        self.generator = OpenAIRoutineGenerator(settings, self.openai)
        self.retriever = KnowledgeRetriever(supabase, self.openai)

    async def _generate(self, facts: dict[str, Any], constraints: dict[str, Any]) -> tuple[dict[str, Any], set[int]]:
        chunks_by_category = await self.retriever.retrieve(facts)
        chunks = [c for chunks in chunks_by_category.values() for c in chunks]
        llm_facts = {k: facts.get(k) for k in LLM_FACT_KEYS}
        routine = await self.generator.generate_routine(llm_facts, constraints, chunks)
        return routine, {int(c["id"]) for c in chunks}

    async def generate_today(self, user_id: str, today: date) -> dict[str, Any]:
        """POST /routine/today. 항상 4종 루틴을 저장·반환한다(빈 화면 0건, NFR-016)."""
        facts = collect_facts(self.supabase, user_id, today)
        constraints = apply_rules(facts)
        request_payload = {k: facts.get(k) for k in LLM_FACT_KEYS}

        source, model, error = "ai", self.settings.llm_model, None
        try:
            routine, allowed = await asyncio.wait_for(self._generate(facts, constraints), TOTAL_TIMEOUT_SEC)
            routine = validate(routine, constraints, allowed)
        except Exception as exc:  # 타임아웃·API 오류·JSON 오류 모두 폴백 (W-ROUTINE-003)
            error = f"{type(exc).__name__}: {exc}"[:500]
            logger.warning("루틴 생성 실패, 폴백 사용: %s", error)
            previous = repository.get_latest_before(self.supabase, user_id, today)
            if previous and previous.get("response"):
                source, routine = "fallback_prev", previous["response"]
            else:
                source, routine = "fallback_template", load_template()
            model = None
            routine = validate(routine, constraints, set())

        saved = repository.save_routine(
            self.supabase, user_id, today,
            source=source, response=routine, model=model,
            prompt_version=PROMPT_VERSION if source == "ai" else None,
            request_payload=request_payload, error_message=error,
        )
        return {**saved, "response": routine}
