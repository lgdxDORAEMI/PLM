"""파이프라인 B ②: 룰 엔진. rules.yaml의 확정 규칙을 입력에 대조해 exclude/limit/require 목록을 만든다.

LLM을 거치지 않으므로 같은 입력이면 결과가 항상 같다. 연산자 정의는 rules.yaml 머리 주석 참고.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

RULES_PATH = Path(__file__).resolve().parent / "rules.yaml"
EFFECTS = ("exclude", "limit", "require")

Facts = dict[str, Any]
Constraints = dict[str, list[dict[str, Any]]]


def load_rules(path: Path = RULES_PATH) -> list[dict]:
    return yaml.safe_load(path.read_text(encoding="utf-8"))["rules"]


def _matches(condition: dict[str, Any], facts: Facts) -> bool:
    for key, expected in condition.items():
        if key.endswith("_any"):
            actual = facts.get(key[: -len("_any")]) or []
            if not set(actual) & set(expected):
                return False
        elif key.endswith("_gte"):
            actual = facts.get(key[: -len("_gte")])
            if actual is None or actual < expected:
                return False
        elif key.endswith("_lte"):
            actual = facts.get(key[: -len("_lte")])
            if actual is None or actual > expected:
                return False
        elif facts.get(key) != expected:
            return False
    return True


def apply_rules(facts: Facts, rules: list[dict] | None = None) -> Constraints:
    """facts(프로필+컨디션 평면 dict) → {"exclude": [...], "limit": [...], "require": [...]}.

    각 항목은 {"category", "target", "reason"(, "keywords")}. 같은 target이 여러 규칙에 걸리면 첫 규칙만 남긴다.
    """
    result: Constraints = {effect: [] for effect in EFFECTS}
    seen: set[tuple[str, str]] = set()
    for rule in rules or load_rules():
        if not _matches(rule["when"], facts):
            continue
        key = (rule["effect"], rule["target"])
        if key in seen:
            continue
        seen.add(key)
        constraint = {"category": rule["category"], "target": rule["target"], "reason": rule["reason"]}
        if rule.get("keywords"):
            constraint["keywords"] = rule["keywords"]
        result[rule["effect"]].append(constraint)
    return result
