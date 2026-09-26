"""파이프라인 B ④: 프롬프트 조립 + ⑤에서 강제할 출력 JSON 스키마.

스키마 키는 frontend 모델·routine_items.payload(docs/api.md 루틴 응답 payload 표)와 같다.
OpenAI json_schema strict 규칙: 모든 객체에 additionalProperties=false, 모든 속성 required.
"""

from __future__ import annotations

import json
from typing import Any

from app.services.routine.inputs import ACTIVITY_CODES, CUSTOM_ACTIVITY
from app.services.routine.meal_catalog import load_meal_catalog, meal_catalog_prompt

# 2026-09-17.1: 4종 한 번 호출 → 카테고리별 4회 동시 호출(생성 8.6초로 타임아웃 잦음)
# 2026-09-18.1: item_key 값 목록 고정(S1), 가사 키 = 활동 코드표(S6), 예정 활동을 {code, label}로 전달
# 2026-09-18.2: 웰컴 카드 팁 호출 추가(S7)
# 2026-09-18.3: 팁에서 스트레칭·운동·메뉴·가사·취침 제외(가이드와 중복 방지)
# 2026-09-19.1: 전일 루틴 완료·모션 요약(yesterday) 입력 추가(S8)
# 2026-09-19.2: 컨디션 수정 시 대상 가이드만 조정하는 수정 호출(EDIT_SYSTEM_PROMPT, S10)
# 2026-09-20.1: K1 — 가장 느린 식단 호출의 출력 분량 제한(문장 길이·태그·주의 개수)
# 2026-09-24.1: 수면 공기청정기 실기기 제어 — value/options를 팀이 확정한 4종으로 안내(강제는 service.validate가 한다)
# 2026-09-25.2: 건강 부위(bodyArea·loads[].area)를 코드 5종으로 고정(화면에 "waist"가 그대로 노출되던 문제)
# 2026-09-25.3: 통증 3점 이상인 모든 부위, 없으면 전신을 건강 집중 항목으로 생성
# 2026-09-26.1: 식사 cautions를 끼니마다 1개 필수로(화면 '오늘 조심할 것'이 늘 비어 있던 문제)
PROMPT_VERSION = "2026-09-26.1"
WEEK_GUIDE_PROMPT_VERSION = "2026-09-25.1"
CATEGORIES = ("meal", "household", "health", "sleep")


def _obj(props: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "properties": props,
        "required": list(props),
        "additionalProperties": False,
    }


def _arr(items: dict[str, Any]) -> dict[str, Any]:
    return {"type": "array", "items": items}


_STR = {"type": "string"}
# item_key는 이전 루틴과 새 루틴을 item_key로 비교(diff)하므로 호출마다 같은 값이어야 한다.
# 수면 환경 종류 코드. 프론트 SleepEnvironmentType enum 이름과 같아야 한다.
SLEEP_ENV_TYPES = ("light", "temperature", "humidity", "sound", "purifier")
SLEEP_ENV_LABELS = {"조명": "light", "온도": "temperature", "습도": "humidity", "소리": "sound", "공기청정기": "purifier"}
# 09-24: 공기청정기는 실기기를 제어하므로 이 4개만 유효하다(취침 예약 타이머는 범위 제외).
# service.validate가 AI 출력과 무관하게 이 값으로 강제한다 — 여기서는 프롬프트 안내용으로만 쓴다.
PURIFIER_OPTIONS = ("조용 모드", "자동", "강풍", "끄기")
MEAL_KEYS = ("meal:breakfast", "meal:lunch", "meal:dinner", "meal:snack")
MEAL_TITLES = tuple(
    item["title"]
    for items in load_meal_catalog().values()
    for item in items
)
HEALTH_KEYS = ("health:waist", "health:pelvis", "health:leg", "health:wrist", "health:whole", "health:rest")  # rest는 fallback.yaml과 동일
# 09-25: bodyArea가 자유 문자열이라 날마다 "허리"와 "waist"가 섞여 저장됐다(화면에 영어 노출).
# 수면 환경 type과 같은 방식으로 코드만 허용하고, 조회할 때 한글로 바꾼다(guide/query_service.py).
BODY_AREA_TYPES = ("waist", "pelvis", "leg", "wrist", "whole")
BODY_AREA_LABELS = {"허리": "waist", "골반": "pelvis", "다리": "leg", "손목": "wrist", "전신": "whole"}
SLEEP_KEY = "sleep:main"
# S6: 활동 코드표 9종 + 직접 입력(custom). 직접 입력이 여러 개면 service._normalize_item_keys가 :2를 붙인다.
HOUSEHOLD_KEYS = tuple(f"household:{code}" for code in (*ACTIVITY_CODES.values(), CUSTOM_ACTIVITY))
_INT = {"type": "integer"}
_SOURCE_IDS = _arr(_INT)

_MEAL_ITEM = _obj(
    {
        "item_key": {"type": "string", "enum": list(MEAL_KEYS)},
        "title": {"type": "string", "enum": list(MEAL_TITLES)},
        "payload": _obj(
            {
                "period": {"type": "string", "enum": ["breakfast", "lunch", "dinner", "snack"]},
                "reasonTitle": _STR,
                "reason": _STR,
                "evidence": _STR,
                "nutritionTags": _arr(_STR),
                "cautions": _arr(_obj({"title": _STR, "description": _STR, "badge": _STR})),
            }
        ),
        "source_ids": _SOURCE_IDS,
    }
)
_HOUSEHOLD_ITEM = _obj(
    {
        "item_key": {"type": "string", "enum": list(HOUSEHOLD_KEYS)},
        "title": _STR,
        "payload": _obj(
            {
                "owner": {"type": "string", "enum": ["self", "appliance", "partner"]},
                "applianceAction": {"type": "string", "enum": ["now", "reserve", "night", "none"]},
                "reason": _STR,
            }
        ),
        "source_ids": _SOURCE_IDS,
    }
)
_HEALTH_ITEM = _obj(
    {
        "item_key": {"type": "string", "enum": list(HEALTH_KEYS)},
        "title": _STR,
        "payload": _obj(
            {
                "bodyArea": {"type": "string", "enum": list(BODY_AREA_TYPES)},
                "loads": _arr(_obj({"area": {"type": "string", "enum": list(BODY_AREA_TYPES)},
                                    "label": _STR, "value": {"type": "number"}})),
                "guide": _STR,
                "durationMin": _INT,
                "reason": _STR,
            }
        ),
        "source_ids": _SOURCE_IDS,
    }
)
_SLEEP = _obj(
    {
        "item_key": {"type": "string", "enum": [SLEEP_KEY]},
        "title": _STR,
        "payload": _obj(
            {
                "recommendedBedtime": _STR,
                # 09-22: type은 코드 5종만. 한글("조명")로 오면 프론트가 전부 조명으로 처리했다.
                "environments": _arr(_obj({"type": {"type": "string", "enum": list(SLEEP_ENV_TYPES)}, "value": _STR, "options": _arr(_STR)})),
                "tips": _arr(_STR),
                "reason": _STR,
            }
        ),
        "source_ids": _SOURCE_IDS,
    }
)

ROUTINE_SCHEMA: dict[str, Any] = _obj(
    {
        "meal": _arr(_MEAL_ITEM),
        "household": _arr(_HOUSEHOLD_ITEM),
        "health": _arr(_HEALTH_ITEM),
        "sleep": _SLEEP,
    }
)


# S7(R4): 웰컴 카드 "오늘 시도해보세요" 팁 1개(FUC-W-HOME-001). 4종 루틴과 별도 호출·별도 실패 처리.
TIP_SCHEMA: dict[str, Any] = _obj({"tip": _obj({"text": _STR, "source_ids": _SOURCE_IDS})})
# 팁은 4종 가이드와 겹치지 않는 생활 행동만. 스트레칭·운동은 건강 가이드(영상 포함, S_stretching_video),
# 메뉴는 식사 가이드, 집안일 분담은 가사 가이드, 취침은 수면 가이드가 맡는다(09-18 결정).
TIP_REQUEST = (
    "위 정보로 홈 화면 '오늘 시도해보세요' 팁 1개를 작성. 오늘 가장 불편한 컨디션 1가지에 대해 오늘 바로 할 수 있는 "
    "생활 행동 1개를 한 문장(40자 안팎)으로. 예: 수분 섭취, 일을 짧게 나눠 쉬기, 앉거나 서는 자세, 옷차림, 실내 환경. "
    "스트레칭·운동·체조, 식사 메뉴·음식, 집안일 분담, 취침 시각은 다른 가이드가 다루므로 쓰지 않는다. "
    "진단·처방·약·수치는 쓰지 않는다. 확정 규칙을 어기지 않는다."
)


# 홈 "이번 주에 알아두세요". 주차 특징 2줄과 주의 1줄 모두 제공된 RAG 문단에 근거해야 한다.
WEEK_GUIDE_SCHEMA: dict[str, Any] = _obj(
    {
        "week_notes": {"type": "array", "items": _STR, "minItems": 2, "maxItems": 2},
        "caution": _STR,
        "source_ids": _SOURCE_IDS,
    }
)
WEEK_GUIDE_SYSTEM_PROMPT = """당신은 PLM 임산부 생활관리 AI '웬즈데이'의 주차별 생활 안내 작성 도구다.
의료 진단이나 처방을 하지 않는다.
규칙:
- 출력은 지정된 JSON 스키마만 사용하고 한국어로 작성한다.
- 제공된 참고 문단에 직접 근거한 내용만 작성한다. 일반 상식이나 기억으로 내용을 보충하지 않는다.
- week_notes는 해당 임신 주차에 나타날 수 있는 일반적인 신체 변화나 생활 특징 2개다.
- caution은 사용자가 일상에서 참고할 안전한 주의사항 1개다.
- 각 문장은 단정하지 않고 개인차가 있음을 전제로 하며 60자 이내로 쓴다.
- 진단, 치료 효과, 약 복용 지시, 근거 문단에 없는 수치를 만들지 않는다.
- 사용한 참고 문단의 id를 source_ids에 넣는다. 적어도 1개 이상의 id를 사용한다.
- 응급 증상은 구체적으로 판정하지 않고 이상 증상이 있으면 의료진과 상담하도록 안내한다."""


def build_week_guide_prompt(week: int, chunks: list[dict[str, Any]]) -> str:
    """임신 주차와 RAG 문단만 전달한다. 프로필·컨디션은 일일 루틴/오늘의 팁에서 별도로 다룬다."""
    lines = [
        f"[id={c['id']}] ({c.get('category', '')}, 출처={c.get('source', '')}) {c['content']}"
        for c in chunks
    ]
    return "\n".join(
        [
            f"## 임신 주차\n{week}주",
            "## 참고 문단\n" + "\n\n".join(lines),
            "## 요청\n홈 화면 '이번 주에 알아두세요'에 표시할 주차 특징 2줄과 주의사항 1줄을 작성하세요.",
        ]
    )


def category_schema(category: str) -> dict[str, Any]:
    """카테고리 1개만 담은 strict 스키마. 응답은 {category: ...} 모양."""
    return _obj({category: ROUTINE_SCHEMA["properties"][category]})

SYSTEM_PROMPT = """당신은 임산부의 하루 생활 루틴을 설계하는 보조 도구다. 의료 진단이나 처방을 하지 않는다.
규칙:
- 출력은 주어진 JSON 스키마만. 한국어.
- meal: 아침(breakfast)·점심(lunch)·저녁(dinner)·밤(snack) 각 1개, 반드시 4개. 밤은 가벼운 간식이나 늦은 저녁이다. 사용자 메시지의 '선택 가능한 식사 메뉴'에서 각 period에 속한 title을 정확히 하나 골라 쓰며 임의 메뉴명을 만들지 않는다. 금지(exclude) 재료는 절대 포함하지 않는다. 제한(limit)은 양을 줄이고 이유를 적는다.
- meal 분량 제한(응답 속도): title 20자 이내, reason·evidence는 각각 한 문장(60자 이내), nutritionTags 3개 이내.
  같은 내용을 여러 항목에 반복하지 않는다.
- meal cautions: 끼니마다 정확히 1개를 채운다(빈 배열 금지) — 화면의 '오늘 조심할 것'에 그대로 나간다.
  title은 조심할 대상 이름 12자 이내(예: 카페인, 찬 음식, 과식), description은 이유와 허용 범위를 한 문장(50자 이내)으로
  적는다(예: 속이 쓰릴 수 있어요. 하루 한 잔까지 괜찮아요). badge는 '주의' 또는 '제한' 중 하나.
  무조건 금지로 쓰지 않고, 진단·수치·약 이름은 쓰지 않는다. 끼니마다 다른 내용을 쓴다.
- household: 사용자가 고른 예정 활동을 각각 owner(self=직접, appliance=가전, partner=가족)로 분류한다. 금지 가사는 self로 두지 않는다.
- household: planned_activities의 각 항목({code, label})마다 1개. item_key는 `household:<code>`(예: household:laundry), 직접 입력(code=custom)은 household:custom. title·설명은 label을 기준으로 쓴다.
- health: 허리·골반·다리·손목 중 통증이 3 이상인 모든 부위를 각각 포함한다. 모두 3 미만이면 health:whole 전신 스트레칭을 포함한다. 금지 활동은 넣지 않는다. 5~15분 내 활동.
- health: bodyArea와 loads[].area는 waist(허리)·pelvis(골반)·leg(다리)·wrist(손목)·whole(전신) 코드로 쓴다. item_key의 부위와 같아야 한다(health:rest는 whole).
- health: yesterday.motion.top_burdened_area(전일 부담이 컸던 부위)가 있으면 오늘 통증과 함께 우선순위에 반영한다.
- household: yesterday.motion.bending_burden_events(전일 허리 숙임 부담 횟수)가 많으면 허리를 숙이는 가사는 partner·appliance를 우선 고려한다.
- yesterday(전일 루틴 완료 현황·모션 요약)는 참고 정보다. 값이 null이면 오늘 입력만으로 판단한다.
- sleep: 권장 취침 시각, 환경 제안값, 팁. environments.type은 light(조명)·temperature(온도)·humidity(습도)·sound(소리)·purifier(공기청정기) 코드로 쓰고 각 1개씩.
- sleep: purifier는 실제 기기를 켜고 끈다. value는 반드시 "조용 모드"/"자동"/"강풍"/"끄기" 중 하나, options도 이 4개 그대로 쓴다. 취침 예약(타이머)은 다루지 않는다.
- 근거 자료(참고 문단)가 주어지면 그 내용에 기반해 작성하고, 사용한 문단의 id만 source_ids에 넣는다. 자료가 없으면 빈 배열.
- 자료에 없는 수치·의학 주장은 만들지 않는다. 산후 관련 내용은 무시한다.
- 응급·위험 신호 판단은 하지 않고 "이상 증상은 의료진 상담" 한 줄만 허용한다."""


def build_user_prompt(
    facts: dict[str, Any],
    constraints: dict[str, list[dict[str, str]]] | None = None,
    chunks: list[dict[str, Any]] | None = None,
    category: str | None = None,
    request: str | None = None,
) -> str:
    """① facts + ② constraints + ③ chunks → 사용자 메시지 1개. category를 주면 그 카테고리만 요청한다.
    request를 주면 마지막 요청 문장을 그것으로 바꾼다(S7 팁)."""
    parts = ["## 사용자 정보(오늘)", json.dumps(facts, ensure_ascii=False)]
    if constraints and any(constraints.values()):
        parts += ["## 확정 규칙(반드시 준수)", json.dumps(constraints, ensure_ascii=False)]
    if chunks:
        lines = [f"[id={c['id']}] ({c.get('category', '')}) {c['content']}" for c in chunks]
        parts += ["## 참고 문단", "\n\n".join(lines)]
    if category == "meal":
        parts += ["## 선택 가능한 식사 메뉴(period별 title 고정)", meal_catalog_prompt()]
    target = category or "meal·household·health·sleep"
    parts += ["## 요청", request or f"위 정보로 오늘의 {target} 루틴을 JSON 스키마에 맞게 작성."]
    return "\n".join(parts)


# S10(R7): 컨디션 수정 호출. 설계 §2.7. 어느 가이드를 얼마나 고칠지는 백엔드(impact.py)가 정하고 LLM은 다시 판단하지 않는다.
EDIT_SYSTEM_PROMPT = """당신은 임산부 생활관리 AI '웬즈데이'의 지정 카테고리 루틴 조정 엔진이다. 의료 진단이나 처방을 하지 않는다.
임신 주차, 현재 전체 컨디션, 이번에 변경된 컨디션, 예정 활동, 이전 target_category 루틴, 확정 규칙과 참고 문단을 사용한다.

[범위와 안전]
1. target_category 외의 meal/household/health/sleep 루틴을 생성하거나 변경하지 않는다.
2. 백엔드가 정한 category_decision.mode(TUNE/REPLAN), strength, direction을 따른다. high는 수정 범위이지 의학적 처치 강도가 아니다.
3. 여러 변경을 함께 고려한다. 같은 카테고리의 악화 신호는 누적하고, 악화와 호전은 서로 상쇄하지 않는다. mixed이면 항목별로 다른 조정을 한다.
4. 이 가이드에 기여한 변경만 수정의 근거로 쓴다. 다른 항목은 현재 상태의 안전 맥락으로만 본다.
5. 확정 규칙(exclude/limit/require)이 항상 우선한다. 참고 문단에 없는 의학적 사실·진단·치료 효과를 만들지 않는다.
6. 이전 루틴을 기준으로 판단하고 불필요한 교체를 피한다. 악화 시 부담을 키우지 않고, 호전 시 제한을 점진적으로 완화한다.
7. 출력은 지정된 JSON 스키마만. 한국어. 사용한 참고 문단의 id만 source_ids에 넣는다.

[TUNE] 기존 item_key와 항목 수를 유지하고, 가능하면 title도 유지한다. 필요한 세부 값만 바꾸고 관련 없는 항목은 그대로 둔다.
[REPLAN] target_category 안에서만 여러 항목을 재평가한다. 부적절한 추천은 바꾸되 기존 item_key의 의미(끼니·부위·가사)는 가능한 한 유지한다.
secondary 영향이면 그 카테고리가 담당할 수 있는 보조 대책만 제공한다.

[카테고리 책임] meal=식사 구성·시점·음식 선택, household=가사 수행·분담·부담, health=움직임·자세·활동 강도·생활 건강, sleep=취침·수면 환경·준비.
item_key 규칙과 카테고리별 기본 규칙은 최초 생성과 같다:
""" + SYSTEM_PROMPT


def build_edit_prompt(
    category: str,
    facts: dict[str, Any],
    decision: dict[str, Any],
    changes: list[dict[str, Any]],
    contributors: list[dict[str, Any]],
    previous: Any,
    constraints: dict[str, list[dict[str, str]]] | None = None,
    chunks: list[dict[str, Any]] | None = None,
) -> str:
    """§2.7 수정 호출 User Prompt. facts = 현재 전체 컨디션(LLM_FACT_KEYS)."""
    dump = lambda value: json.dumps(value, ensure_ascii=False)  # noqa: E731
    parts = [
        f"다음 정보를 기준으로 {category} 루틴만 조정하세요.",
        f"[카테고리 결정] {dump(decision)}",
        f"[이번에 변경된 전체 컨디션] {dump(changes)}",
        f"[이 가이드에 기여한 변경과 primary/secondary 관계] {dump(contributors)}",
        f"[현재 전체 컨디션·예정 활동] {dump(facts)}",
        f"[기존 {category} 루틴] {dump(previous)}",
        f"[현재 확정 규칙] {dump(constraints or {})}",
    ]
    if chunks:
        lines = [f"[id={c['id']}] ({c.get('category', '')}) {c['content']}" for c in chunks]
        parts += ["[참고 문단]", "\n\n".join(lines)]
    if category == "meal":
        parts += ["[선택 가능한 식사 메뉴(period별 title 고정)]", meal_catalog_prompt()]
    parts.append(
        "악화와 호전을 하나의 점수로 상쇄하지 마세요. category_decision의 mode·strength 범위에서 기존 루틴을 필요한 만큼만 "
        "조정하세요. 다른 카테고리의 루틴을 출력하거나 관련 없는 변화를 수정 이유로 삼지 마세요. 확정 규칙을 준수하고, "
        "근거 밖 의학적 내용을 추가하지 마세요. 반드시 지정된 JSON 스키마만 출력하세요."
    )
    return "\n".join(parts)
