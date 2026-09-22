"""챗봇 S5: 식사 모드 전용 메모리. 설계: docs/chatbot/chatbot_guide.md S5.

메모리 1 보던 끼니 카드(routine_items), 2 확정 규칙(웬즈데이 rules.yaml), 3 과거 메뉴 선택(recommendation_feedback)을
읽어 LLM 지시문으로 만든다. 메모리 4 대화 이력은 service가 같은 날짜 전체에서 넘긴다. 모두 읽기만 한다.
"""

from __future__ import annotations

from datetime import date
from typing import Any

import httpx
from postgrest.exceptions import APIError
from supabase import Client

from app.domains.errors import DomainStorageError
from app.services.routine.rules import apply_rules
from app.services.routine.service import _banned_words

FEEDBACK_LIMIT = 10
FEEDBACK_LABELS = {"meal_accept": "고름", "meal_replace": "바꿔서 고름", "meal_reject": "안 고름"}
CARD_ACTIONS = ["이걸로 할게요", "다른 메뉴 보기"]  # 카드가 있을 때 서버가 고정으로 붙인다(LLM이 만들지 않음)
BANNED_REPLY = "조건에 맞는 메뉴를 찾지 못했어요. 다시 요청해 주세요."


def load(client: Client, user_id: str, target_date: date, item_id: str, facts: dict[str, Any]) -> dict[str, Any]:
    """{rules: LLM 지시문, banned: 금지 단어}. item_id는 service가 이미 오늘·본인·식사 항목인지 확인했다."""
    try:
        item, feedback = _read(client, user_id, target_date, item_id)
    except (APIError, httpx.HTTPError) as error:
        raise DomainStorageError("대화 저장소에 연결할 수 없습니다.") from error
    constraints = apply_rules(facts)
    meal_only = {effect: [c for c in rows if c.get("category") == "meal"] for effect, rows in constraints.items()}
    return {"rules": _rules(item, meal_only, feedback), "banned": _banned_words(meal_only)}


def _read(client: Client, user_id: str, target_date: date, item_id: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    item = (
        client.table("routine_items").select("title", "payload").eq("id", item_id).eq("user_id", user_id)
        .eq("date", target_date.isoformat()).limit(1).execute().data
    )[0]
    feedback = (
        client.table("recommendation_feedback").select("kind", "payload").eq("user_id", user_id)
        .in_("kind", list(FEEDBACK_LABELS)).order("created_at", desc=True).limit(FEEDBACK_LIMIT).execute().data
    )
    return item, feedback


def _rules(item: dict[str, Any], constraints: dict[str, list[dict[str, Any]]], feedback: list[dict[str, Any]]) -> str:
    payload = item.get("payload") or {}
    lines = [
        "- 이 대화는 식사 가이드에서 들어온 메뉴 재추천이다. 사용자가 불편을 말하면 조건에 맞는 새 메뉴 1개를 recommendation에 담는다.",
        "- 메뉴를 묻지 않는 단순 질문이면 recommendation은 null.",
        "- 이미 추천한 메뉴([최근 대화]의 [추천: …])와 [보던 끼니]는 다시 추천하지 않는다.",
        "- [오늘 4종 가이드]의 meal은 오늘 다른 끼니 메뉴다. 선택지가 아니다. 이와 겹치지 않는 새 메뉴를 만든다.",
        "- 금지 재료는 절대 쓰지 않는다. 제한 재료는 양을 줄이고 이유를 reason에 적는다.",
        "- recommendation은 추천일 뿐이다. 메뉴를 바꿨다고 말하지 않는다. 사용자가 직접 고른다.",
        "- recommendation.title 20자 이내, reason 한 문장, nutritionTags 3개 이내.",
        "- 가사·건강·수면 루틴 변경 요청은 \"아직 지원하지 않아요\"라고 안내한다.",
        f"[보던 끼니] {item['title']} / 이유: {payload.get('reason', '')} / 태그: {', '.join(payload.get('nutritionTags') or [])}"
        f" / 조심할 것: {', '.join(c.get('title', '') for c in payload.get('cautions') or [])}",
        "[금지 재료] " + (", ".join(f"{c['target'].split(':', 1)[-1]}({c['reason']})" for c in constraints["exclude"]) or "없음"),
        "[제한 재료] " + (", ".join(f"{c['target'].split(':', 1)[-1]}({c['reason']})" for c in constraints["limit"]) or "없음"),
        "[과거 메뉴 선택] " + (", ".join(
            f"{FEEDBACK_LABELS[f['kind']]}: {(f.get('payload') or {}).get('title', '')}" for f in feedback
        ) or "없음"),
    ]
    return "\n".join(lines)


def is_banned(recommendation: dict[str, Any], banned: list[str]) -> bool:
    """웬즈데이 validate와 같은 기준: 이름(title·nutritionTags)만 본다. reason 문장은 보지 않는다."""
    name = " ".join([recommendation.get("title") or "", *(recommendation.get("nutritionTags") or [])])
    return any(word in name for word in banned)
