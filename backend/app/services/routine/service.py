"""파이프라인 B 조율: ① 입력 → ② 룰 → ③ RAG → ④⑤ 생성 → ⑥ 검증·폴백 → ⑦ 저장."""

from __future__ import annotations

import asyncio
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
# S7: 팁은 4종 루틴과 동시에 만든다. 루틴이 끝난 뒤 팁을 이만큼만 더 기다리고, 못 받으면 tip=None(루틴은 그대로 ai).
TIP_GRACE_SEC = 1.0
TIP_CHUNKS_PER_CATEGORY = 2

# NFR-014: 이 키만 LLM에 보낸다. 자유 텍스트 진료 메모(medical_note)는 W-PROFILE-006 요구대로 포함.
LLM_FACT_KEYS = (
    "week", "is_first_pregnancy", "is_multiple_pregnancy", "allergies", "medical_conditions", "medical_note",
    "nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue", "mood", "sleep_quality",
    "planned_activities",
)


def load_template() -> dict[str, Any]:
    return yaml.safe_load(FALLBACK_PATH.read_text(encoding="utf-8"))


def _banned_words(constraints: dict[str, list[dict[str, Any]]]) -> list[str]:
    return [
        word
        for c in constraints.get("exclude", [])
        for word in [c["target"].split(":", 1)[-1], *c.get("keywords", [])]
        if word
    ]


def validate_tip(
    tip: dict[str, Any] | None,
    constraints: dict[str, list[dict[str, Any]]],
    allowed_source_ids: set[int],
) -> dict[str, Any] | None:
    """S7: 팁은 한 문장이라 전체 문장에서 금지어를 찾는다(걸리면 None). 없는 source_id는 뺀다."""
    text = ((tip or {}).get("text") or "").strip()
    if not text or any(word in text for word in _banned_words(constraints)):
        return None
    ids = [int(i) for i in tip.get("source_ids") or [] if int(i) in allowed_source_ids]
    return {"text": text, "source_ids": ids}


def validate(
    routine: dict[str, Any],
    constraints: dict[str, list[dict[str, Any]]],
    allowed_source_ids: set[int],
) -> dict[str, Any]:
    """⑥ 검증: exclude 대상이 남은 항목 제거, 없는 source_id 제거. 원본은 바꾸지 않는다."""
    # 이름(title·nutritionTags)만 검사한다. reason 같은 설명문까지 보면 "갑각류를 피했어요"에 걸려 정상 항목이 지워진다.
    # ponytail: 단어 부분일치라 keywords에 없는 메뉴명(예: 해물찜)은 못 거른다 → 누락이 보이면 rules.yaml keywords에 추가.
    # 코드형 target(activity:walk)은 한국어 제목과 안 맞아 keywords가 없으면 걸러지지 않는다.
    banned = _banned_words(constraints)

    def keep(entry: dict[str, Any]) -> bool:
        name = " ".join([entry.get("title") or "", *((entry.get("payload") or {}).get("nutritionTags") or [])])
        return not any(word in name for word in banned)

    def clean(entry: dict[str, Any]) -> dict[str, Any]:
        ids = [int(i) for i in entry.get("source_ids") or [] if int(i) in allowed_source_ids]
        return {**entry, "source_ids": ids}

    result: dict[str, Any] = {}
    for category in ("meal", "household", "health"):
        result[category] = [clean(e) for e in routine.get(category) or [] if keep(e)]
    sleep = routine.get("sleep") or {}
    result["sleep"] = clean(sleep) if sleep else {}
    return result


def _normalize_item_keys(routine: dict[str, Any]) -> dict[str, Any]:
    """item_key를 코드가 확정한다. 완료 기록·diff가 키로 짝을 맞추므로 항목을 절대 버리지 않게 한다.

    - meal: AI가 붙인 키 대신 payload.period(아침·점심·저녁·간식, 스키마 enum)로 만든다.
      09-18 실DB에서 AI가 세 끼에 같은 키를 붙여 중복 처리에서 두 끼가 버려졌다.
    - household: `household:` 접두사 보정(활동 코드표 미확정이라 스키마로 강제 못 함).
    - 같은 카테고리에서 키가 겹치면 뒤 항목에 `:2`, `:3`을 붙인다.
    """
    result = dict(routine)
    for category in ("meal", "household", "health"):
        seen: dict[str, int] = {}
        fixed = []
        for order, entry in enumerate(routine.get(category) or []):
            key = (entry.get("item_key") or "").strip()
            period = (entry.get("payload") or {}).get("period")
            if category == "meal" and period:
                key = f"meal:{period}"
            elif not key:
                key = f"{category}:{order}"
            elif not key.startswith(f"{category}:"):
                key = f"{category}:{key.split(':')[-1]}"
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > 1:
                key = f"{key}:{seen[key]}"
            fixed.append({**entry, "item_key": key})
        result[category] = fixed
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

    async def _safe_tip(self, facts: dict[str, Any], constraints: dict[str, Any], chunks: list[dict[str, Any]]):
        try:
            return await self.generator.generate_tip(facts, constraints, chunks)
        except Exception as exc:  # 팁 실패는 루틴 폴백 사유가 아니다
            logger.warning("오늘의 팁 생성 실패, tip=None: %s", f"{type(exc).__name__}: {exc}"[:200])
            return None

    async def _generate(
        self, facts: dict[str, Any], constraints: dict[str, Any], deadline: float
    ) -> tuple[dict[str, Any], set[int]]:
        chunks_by_category = await self.retriever.retrieve(facts)
        llm_facts = {k: facts.get(k) for k in LLM_FACT_KEYS}
        tip_chunks = list({c["id"]: c for chunks in chunks_by_category.values()
                           for c in chunks[:TIP_CHUNKS_PER_CATEGORY]}.values())
        tip_task = asyncio.create_task(self._safe_tip(llm_facts, constraints, tip_chunks))
        try:
            routine = await self.generator.generate_routine(llm_facts, constraints, chunks_by_category)
        except BaseException:
            tip_task.cancel()
            raise
        loop = asyncio.get_running_loop()
        grace = max(0.0, min(TIP_GRACE_SEC, deadline - loop.time() - 0.1))
        try:
            tip = await asyncio.wait_for(tip_task, grace)
        except asyncio.TimeoutError:
            logger.warning("오늘의 팁이 제시간에 오지 않음, tip=None")
            tip = None
        return {**routine, "tip": tip}, {int(c["id"]) for chunks in chunks_by_category.values() for c in chunks}

    async def generate_today(self, user_id: str, today: date) -> dict[str, Any]:
        """POST /routine/today. 항상 4종 루틴을 저장·반환한다(빈 화면 0건, NFR-016)."""
        facts = collect_facts(self.supabase, user_id, today)
        constraints = apply_rules(facts)
        request_payload = {k: facts.get(k) for k in LLM_FACT_KEYS}

        source, model, error = "ai", self.settings.llm_model, None
        deadline = asyncio.get_running_loop().time() + TOTAL_TIMEOUT_SEC
        try:
            generated, allowed = await asyncio.wait_for(self._generate(facts, constraints, deadline), TOTAL_TIMEOUT_SEC)
            routine = _normalize_item_keys(validate(generated, constraints, allowed))
            routine["tip"] = validate_tip(generated.get("tip"), constraints, allowed)
        except Exception as exc:  # 타임아웃·API 오류·JSON 오류 모두 폴백 (W-ROUTINE-003)
            error = f"{type(exc).__name__}: {exc}"[:500]
            logger.warning("루틴 생성 실패, 폴백 사용: %s", error)
            previous = repository.get_latest_before(self.supabase, user_id, today)
            if previous and previous.get("response"):
                source, routine = "fallback_prev", previous["response"]
            else:
                source, routine = "fallback_template", load_template()
            model = None
            routine = _normalize_item_keys(validate(routine, constraints, set()))
            routine["tip"] = None  # 폴백에는 팁이 없다(전일 팁을 그대로 쓰지 않음). 앱은 기본 문구를 쓴다

        saved = repository.save_routine(
            self.supabase, user_id, today,
            source=source, response=routine, model=model,
            prompt_version=PROMPT_VERSION if source == "ai" else None,
            request_payload=request_payload, error_message=error,
        )
        return {**saved, "response": routine}
