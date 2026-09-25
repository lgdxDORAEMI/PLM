"""파이프라인 B 조율: ① 입력 → ② 룰 → ③ RAG → ④⑤ 생성 → ⑥ 검증·폴백 → ⑦ 저장."""

from __future__ import annotations

import asyncio
import logging
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from openai import AsyncOpenAI
from supabase import Client

from app.core.config import Settings
from app.services.routine import repository
from app.services.routine.generator import OpenAIRoutineGenerator
from app.services.routine.impact import load_impact_map, resolve_impact
from app.services.routine.inputs import collect_facts, collect_yesterday
from app.services.routine.meal_catalog import attach_meal_images
from app.services.routine.prompt import CATEGORIES, MEAL_KEYS, PROMPT_VERSION, PURIFIER_OPTIONS
from app.services.routine.retriever import KnowledgeRetriever
from app.services.routine.rules import apply_rules

logger = logging.getLogger(__name__)

FALLBACK_PATH = Path(__file__).resolve().parent / "fallback.yaml"
VIDEO_PATH = Path(__file__).resolve().parent / "stretching_videos.yaml"
# NFR-001 p95 10초. 임베딩+검색+생성 전체 상한. 넘으면 폴백.
TOTAL_TIMEOUT_SEC = 9.5
# S7: 팁은 4종 루틴과 동시에 만든다. 루틴이 끝난 뒤 팁을 이만큼만 더 기다리고, 못 받으면 tip=None(루틴은 그대로 ai).
TIP_GRACE_SEC = 1.0
TIP_CHUNKS_PER_CATEGORY = 2

# NFR-014: 이 키만 LLM에 보낸다. 자유 텍스트 진료 메모(medical_note)는 W-PROFILE-006 요구대로 포함.
LLM_FACT_KEYS = (
    "week", "is_first_pregnancy", "is_multiple_pregnancy", "allergies", "medical_conditions", "medical_note",
    "nausea", "waist_pain", "pelvis_pain", "leg_pain", "wrist_pain", "fatigue",  # K3: sleep_quality 제외, 09-22: mood 제외
    "planned_activities", "yesterday",
)

PAIN_FACT_KEYS = ("waist_pain", "pelvis_pain", "leg_pain", "wrist_pain")
PAIN_PARTS = dict(zip(PAIN_FACT_KEYS, ("waist", "pelvis", "leg", "wrist")))
HEALTH_DEFAULTS = {
    "waist": ("허리 이완 스트레칭", "허리를 통증 없는 범위에서 천천히 이완해요."),
    "pelvis": ("골반 이완 스트레칭", "골반을 통증 없는 범위에서 천천히 움직여요."),
    "leg": ("다리 이완 스트레칭", "다리를 무리하지 않는 범위에서 천천히 풀어줘요."),
    "wrist": ("손목 이완 스트레칭", "손목을 통증 없는 범위에서 천천히 움직여요."),
    "whole": ("전신 저강도 스트레칭", "전신을 천천히 움직이고 불편하면 즉시 멈춰요."),
}


def ensure_health_focus_items(
    routine: dict[str, Any], facts: dict[str, Any]
) -> dict[str, Any]:
    """3점 이상 통증 부위를 집중 항목으로 표시하고, 없으면 전신을 집중 항목으로 보장한다."""
    focus_parts = {
        part
        for key, part in PAIN_PARTS.items()
        if isinstance(facts.get(key), (int, float)) and facts[key] >= 3
    }
    if not focus_parts:
        focus_parts = {"whole"}
    health = list(routine.get("health") or [])

    def health_part(item: dict[str, Any]) -> str:
        payload_part = str((item.get("payload") or {}).get("bodyArea") or "")
        if payload_part in HEALTH_DEFAULTS:
            return payload_part
        key_parts = str(item.get("item_key") or "").split(":")
        return key_parts[1] if len(key_parts) > 1 else ""

    existing_parts = {health_part(item) for item in health}
    for part in HEALTH_DEFAULTS:
        if part not in focus_parts or part in existing_parts:
            continue
        title, guide = HEALTH_DEFAULTS[part]
        health.append({
            "item_key": f"health:{part}",
            "title": title,
            "payload": {
                "bodyArea": part,
                "loads": [],
                "guide": guide,
                "durationMin": 10,
                "reason": "오늘의 집중 부위에 맞춰 추천해요.",
            },
            "source_ids": [],
        })
    marked = []
    unmarked_focus_parts = set(focus_parts)
    for item in health:
        part = health_part(item)
        payload = item.get("payload") or {}
        is_focus = part in unmarked_focus_parts
        unmarked_focus_parts.discard(part)
        marked.append({
            **item,
            "payload": {**payload, "isFocus": is_focus},
        })
    return {**routine, "health": marked}


def load_template() -> dict[str, Any]:
    return yaml.safe_load(FALLBACK_PATH.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def load_videos() -> dict[str, dict[str, Any]]:
    """S_stretching_video: 부위별 대표 활동 영상. url이 빈 부위는 붙이지 않는다."""
    data = yaml.safe_load(VIDEO_PATH.read_text(encoding="utf-8")) or {}
    return {part: v for part, v in (data.get("videos") or {}).items() if (v or {}).get("url")}


def attach_videos(routine: dict[str, Any]) -> dict[str, Any]:
    """health 항목의 item_key(health:<부위>, 중복이면 :2)로 영상을 찾아 payload.video에 넣는다. AI는 URL을 만들지 않는다."""
    videos = load_videos()
    if not videos:
        return routine
    items = []
    for entry in routine.get("health") or []:
        part = (entry.get("item_key") or "").split(":")[1:2]
        video = videos.get(part[0]) if part else None
        items.append({**entry, "payload": {**(entry.get("payload") or {}), "video": video}} if video else entry)
    return {**routine, "health": items}


def template_household(activities: list[dict[str, str]] | None) -> list[dict[str, Any]] | None:
    """K8: 폴백 가사 항목을 예정 활동 코드로 만든다. 키가 AI 결과와 같아 재생성 때 삭제·추가로 잡히지 않는다.

    예정 활동이 없으면 None(= fallback.yaml의 일반 문구 유지).
    """
    if not activities:
        return None
    return [
        {
            "item_key": f"household:{a['code']}",
            "title": a["label"],
            "payload": {
                "owner": "partner",
                "applianceAction": "none",
                "reason": "AI 추천을 불러오지 못했습니다. 무리가 되면 가족과 나눠 주세요.",
            },
            "source_ids": [],
        }
        for a in activities
    ]


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


def _normalize_purifier(sleep: dict[str, Any]) -> dict[str, Any]:
    """공기청정기는 실기기를 제어하므로 AI 출력과 무관하게 PURIFIER_OPTIONS 4종으로 고정한다.

    AI가 다른 문구를 주거나 purifier 항목을 아예 안 줘도(스키마가 개수를 강제하지 않는다)
    항상 이 중 하나가 남는다 — 폴백 템플릿도 validate()를 거치므로 이 경로 하나로 충분하다.
    """
    payload = sleep.get("payload") or {}
    environments = payload.get("environments") or []
    rest = [e for e in environments if e.get("type") != "purifier"]
    existing = next((e for e in environments if e.get("type") == "purifier"), None)
    value = (existing or {}).get("value")
    if value not in PURIFIER_OPTIONS:
        value = PURIFIER_OPTIONS[1]  # "자동" — AI가 못 주거나 목록 밖 값을 준 경우의 기본값
    rest.append({"type": "purifier", "value": value, "options": list(PURIFIER_OPTIONS)})
    return {**sleep, "payload": {**payload, "environments": rest}}


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
    result["sleep"] = _normalize_purifier(clean(sleep)) if sleep else {}
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
        """POST /routine/today. 항상 4종 루틴을 저장·반환한다(빈 화면 0건, NFR-016).

        그날 확정 전 루틴이 있으면 컨디션 수정 경로(S10): 바뀐 가이드만 다시 만든다.
        """
        facts = collect_facts(self.supabase, user_id, today)
        facts["yesterday"] = collect_yesterday(self.supabase, user_id, today)
        constraints = apply_rules(facts)
        request_payload = {k: facts.get(k) for k in LLM_FACT_KEYS}

        base = repository.get_edit_base(self.supabase, user_id, today)
        if base and base.get("confirmed_at") is None and base.get("response") and (
            base.get("source") == "ai" or (base.get("request_payload") or {}).get("failed_categories")
        ):
            return await self._edit_today(user_id, today, facts, constraints, request_payload, base)
        # 오늘 첫 생성, 확정 후 새 루틴(FUC-W-COND-004), 직전이 폴백(재시도)이면 4종 전체 생성.

        source, model, error = "ai", self.settings.llm_model, None
        deadline = asyncio.get_running_loop().time() + TOTAL_TIMEOUT_SEC
        try:
            generated, allowed = await asyncio.wait_for(self._generate(facts, constraints, deadline), TOTAL_TIMEOUT_SEC)
            routine = ensure_health_focus_items(
                validate(generated, constraints, allowed), facts
            )
            routine = attach_videos(attach_meal_images(_normalize_item_keys(routine)))
            routine["tip"] = validate_tip(generated.get("tip"), constraints, allowed)
        except Exception as exc:  # 타임아웃·API 오류·JSON 오류 모두 폴백 (W-CALLBACK-001)
            error = f"{type(exc).__name__}: {exc}"[:500]
            logger.warning("루틴 생성 실패, 폴백 사용: %s", error)
            previous = repository.get_latest_before(self.supabase, user_id, today)
            if previous and previous.get("response"):
                source, routine = "fallback_prev", previous["response"]
            else:
                source, routine = "fallback_template", load_template()
                household = template_household(facts.get("planned_activities"))
                if household:
                    routine = {**routine, "household": household}
            model = None
            routine = ensure_health_focus_items(
                validate(routine, constraints, set()), facts
            )
            routine = attach_videos(attach_meal_images(_normalize_item_keys(routine)))
            routine["tip"] = None  # 폴백에는 팁이 없다(전일 팁을 그대로 쓰지 않음). 앱은 기본 문구를 쓴다

        saved = repository.save_routine(
            self.supabase, user_id, today,
            source=source, response=routine, model=model,
            prompt_version=PROMPT_VERSION if source == "ai" else None,
            request_payload=request_payload, error_message=error,
        )
        return {**saved, "response": routine}

    # ---- S10(R7): 컨디션 수정 경로 -------------------------------------------------------------

    async def _edit_today(
        self, user_id: str, today: date, facts: dict[str, Any], constraints: dict[str, Any],
        request_payload: dict[str, Any], base: dict[str, Any],
    ) -> dict[str, Any]:
        previous_payload = base.get("request_payload") or {}
        impact = resolve_impact(previous_payload, request_payload)
        targets = {c: d for c, d in impact["category_impacts"].items() if d["mode"] != "KEEP"}
        # 직전 수정에서 실패한 가이드는 컨디션이 그대로여도 다시 시도한다(재시도 버튼).
        for category, decision in (previous_payload.get("failed_categories") or {}).items():
            targets.setdefault(category, decision)
        # 09-22: 식사 4끼 필수 이전 버전으로 만든 루틴(3끼)은 입덧이 안 바뀌어도 식사를 다시 만든다.
        # 새 버전인데 끼니가 빠진 경우(알레르기 검증으로 제거 등)는 매 수정마다 다시 만들지 않도록 제외한다.
        if (
            "meal" not in targets
            and base.get("prompt_version")  # 폴백·실패 행(None)은 내용 버전을 알 수 없어 건너뛴다
            and base["prompt_version"] < MEAL4_PROMPT_VERSION
            and _missing_meals(base.get("response") or {})
        ):
            targets["meal"] = {**impact["category_impacts"]["meal"], "mode": "REPLAN", "strength": "low", "contributors": []}
        if not targets:  # 결정1: 바뀐 것이 없으면 호출·저장·알림 없이 현재 루틴 그대로
            row = {k: v for k, v in base.items() if k != "request_payload"}
            return {**row, "unchanged": True}

        previous = base["response"]
        deadline = asyncio.get_running_loop().time() + TOTAL_TIMEOUT_SEC
        try:
            results, tip, allowed = await asyncio.wait_for(
                self._generate_edit(facts, constraints, impact, targets, previous, deadline), TOTAL_TIMEOUT_SEC
            )
        except Exception as exc:  # 검색 실패·전체 시간 초과 → 대상 전부 실패로 처리
            logger.warning("루틴 수정 실패: %s", f"{type(exc).__name__}: {exc}"[:200])
            results, tip, allowed = {}, None, set()

        merged = {c: previous.get(c) for c in CATEGORIES}
        merged.update(results)
        failed = {c: d for c, d in targets.items() if c not in results}
        allowed |= _source_ids(previous)
        routine = validate(merged, constraints, allowed)
        # 결정2: 실패한 가이드는 직전 내용을 현재 규칙으로 검사해 유지하고, 다 걸러져 비면 템플릿의 그 가이드.
        if failed:
            template = validate(load_template(), constraints, set())
            for category in failed:
                if not routine.get(category):
                    routine[category] = template[category]
        routine = ensure_health_focus_items(routine, facts)
        routine = attach_videos(attach_meal_images(_normalize_item_keys(routine)))
        routine["tip"] = validate_tip(tip, constraints, allowed)

        generated = [c for c in targets if c in results]
        source = "ai" if generated else "fallback_prev"  # fallback_prev = 전일 또는 직전 버전 유지
        error = f"수정 실패 가이드: {', '.join(failed)}" if failed else None
        saved = repository.save_routine(
            self.supabase, user_id, today,
            source=source, response=routine,
            model=self.settings.llm_model if generated else None,
            prompt_version=PROMPT_VERSION if generated else None,
            request_payload={
                **request_payload,
                "impact": impact,
                "generated_categories": generated,
                **({"failed_categories": failed} if failed else {}),
            },
            error_message=error,
            change_reason={
                "categories": list(targets),
                "conditions": [c["key"] for c in impact["changed_conditions"]],
            },
        )
        return {**saved, "response": routine}

    async def _generate_edit(
        self, facts: dict[str, Any], constraints: dict[str, Any], impact: dict[str, Any],
        targets: dict[str, dict[str, Any]], previous: dict[str, Any], deadline: float,
    ) -> tuple[dict[str, Any], dict[str, Any] | None, set[int]]:
        """대상 가이드만 검색·수정 호출을 동시에. 가이드별로 성공한 것만 돌려준다(부분 실패 허용)."""
        loop = asyncio.get_running_loop()
        chunks_by_category = await self.retriever.retrieve(facts, list(targets))
        llm_facts = {k: facts.get(k) for k in LLM_FACT_KEYS}
        tip_chunks = list({c["id"]: c for chunks in chunks_by_category.values()
                           for c in chunks[:TIP_CHUNKS_PER_CATEGORY]}.values())
        tip_task = asyncio.create_task(self._safe_tip(llm_facts, constraints, tip_chunks))
        tasks = {
            category: asyncio.create_task(self.generator.generate_edit(
                category, llm_facts, _decision(decision), impact["changed_conditions"],
                _contributors(category, decision, impact["changed_conditions"]),
                previous.get(category), constraints, chunks_by_category.get(category),
            ))
            for category, decision in targets.items()
        }
        done, pending = await asyncio.wait(tasks.values(), timeout=max(0.0, deadline - loop.time() - 0.1))
        for task in pending:
            task.cancel()
        results = {}
        for category, task in tasks.items():
            if task in done and task.exception() is None:
                results[category] = task.result()
            else:
                reason = task.exception() if task in done else "시간 초과"
                logger.warning("가이드 수정 실패(%s), 직전 내용 유지: %s", category, str(reason)[:200])
        grace = max(0.0, min(TIP_GRACE_SEC, deadline - loop.time() - 0.1))
        try:
            tip = await asyncio.wait_for(tip_task, grace)
        except asyncio.TimeoutError:
            tip = None
        allowed = {int(c["id"]) for chunks in chunks_by_category.values() for c in chunks}
        return results, tip, allowed


def _decision(decision: dict[str, Any]) -> dict[str, Any]:
    return {k: decision[k] for k in ("mode", "strength", "direction", "worsening_pressure", "improvement_pressure")}


MEAL4_PROMPT_VERSION = "2026-09-22.2"  # 식사 4끼(밤) 필수가 들어간 프롬프트 버전


def _missing_meals(routine: dict[str, Any]) -> bool:
    """아침·점심·저녁·밤(MEAL_KEYS) 중 빠진 끼니가 있는가."""
    return not set(MEAL_KEYS) <= {m.get("item_key") for m in routine.get("meal") or []}


def _contributors(category: str, decision: dict[str, Any], changes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """이 가이드에 기여한 변경 + primary/secondary 관계(§2.7 category_contributors_json)."""
    conditions = load_impact_map()["conditions"]
    by_key = {c["key"]: c for c in changes}
    result = []
    for key in decision.get("contributors", []):
        if key == "planned_activities":
            result.append({"key": key, "relation": "primary", "change": "예정 활동 목록 변경"})
            continue
        relation = "primary" if category in conditions[key]["primary"] else "secondary"
        result.append({**by_key.get(key, {"key": key, "change": "직전 수정에서 실패해 재시도"}), "relation": relation})
    return result


def _source_ids(routine: dict[str, Any]) -> set[int]:
    ids = set()
    for category in CATEGORIES:
        entries = routine.get(category) or []
        for entry in entries if isinstance(entries, list) else [entries]:
            ids.update(int(i) for i in entry.get("source_ids") or [])
    return ids
