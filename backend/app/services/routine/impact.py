"""웬즈데이 AI S9(R6): 이전·현재 컨디션 비교 → 가이드 4종별 KEEP/TUNE/REPLAN 판단.

이전 컨디션은 그날 최신 revision의 daily_routines.request_payload에서 읽는다(daily_conditions는 덮어쓰기라
이전 값이 남지 않음, 09-19 결정). 실제 생성 연결은 S10. 악화·호전 압력은 서로 상쇄하지 않는다.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

from app.services.routine.prompt import CATEGORIES

IMPACT_MAP_PATH = Path(__file__).resolve().parent / "impact_map.yaml"


@lru_cache(maxsize=1)
def load_impact_map() -> dict[str, Any]:
    return yaml.safe_load(IMPACT_MAP_PATH.read_text(encoding="utf-8"))


def _activity_codes(facts: dict[str, Any]) -> list[str]:
    return sorted(a["code"] if isinstance(a, dict) else str(a) for a in facts.get("planned_activities") or [])


def _decide(worse: float, better: float, replan_signal: bool, cfg: dict[str, Any]) -> dict[str, Any]:
    big, small = max(worse, better), min(worse, better)
    if replan_signal or big >= cfg["replan_pressure"]:
        mode = "REPLAN"
    elif big > 0:
        mode = "TUNE"
    else:
        mode = "KEEP"
    if big == 0:
        strength = "none"
    elif big < cfg["strength"]["medium"]:
        strength = "low"
    elif big < cfg["strength"]["high"]:
        strength = "medium"
    else:
        strength = "high"
    if big == 0:
        direction = "unchanged"
    elif small > 0 and small >= big / 2:
        direction = "mixed"
    else:
        direction = "worsened" if worse >= better else "improved"
    return {"mode": mode, "strength": strength, "direction": direction}


def resolve_impact(previous: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
    """previous·current = 컨디션 점수 + planned_activities를 담은 facts. §2.5 JSON 모양으로 돌려준다."""
    cfg = load_impact_map()
    scores, weights = cfg["scores"], cfg["weights"]
    has_chores = bool(current.get("planned_activities"))
    pressure = {c: {"worse": 0.0, "better": 0.0, "replan": False, "contributors": []} for c in CATEGORIES}

    changed = []
    for key, rule in cfg["conditions"].items():
        before, after = previous.get(key), current.get(key)
        if before is None or after is None or before == after:
            continue
        delta = after - before
        crossed = [n for n in (4, 5) if (before >= n) != (after >= n)]
        impact = (scores["one_step"] if abs(delta) == 1 else scores["multi_step"]) + sum(
            scores[f"cross_{n}"] for n in crossed
        )
        direction = "worsened" if delta > 0 else "improved"
        entry = {"key": key, "from": before, "to": after, "direction": direction, "impact": impact}
        if crossed:
            entry["threshold_crossed"] = True
        changed.append(entry)

        side = "worse" if delta > 0 else "better"
        for category in rule["primary"]:
            pressure[category][side] += impact * weights["primary"]
            pressure[category]["replan"] |= abs(delta) >= 2 or bool(crossed)
            pressure[category]["contributors"].append(key)
        for category in rule.get("secondary", []):
            if category in cfg["secondary_needs_chores"] and not has_chores:
                continue
            pressure[category][side] += impact * weights["secondary"]
            pressure[category]["contributors"].append(key)

    if _activity_codes(previous) != _activity_codes(current):
        target = pressure[cfg["activities_replan"]]
        target["replan"] = True
        target["contributors"].append("planned_activities")

    impacts = {}
    for category, p in pressure.items():
        impacts[category] = {
            **_decide(p["worse"], p["better"], p["replan"], cfg),
            "worsening_pressure": p["worse"],
            "improvement_pressure": p["better"],
            "contributors": p["contributors"],
        }
    return {"changed_conditions": changed, "category_impacts": impacts}
