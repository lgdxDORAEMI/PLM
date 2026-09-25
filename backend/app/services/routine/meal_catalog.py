"""식사 후보 메뉴와 Supabase Storage 이미지의 단일 매핑.

DB에는 버킷 내부 ``imagePath``만 저장하고, API 응답 시 현재 Supabase 공개 URL을
조합한다. LLM은 경로나 URL을 만들지 않는다.
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any
from urllib.parse import quote

import yaml

CATALOG_PATH = Path(__file__).resolve().parent / "meal_candidates.yaml"
MEAL_IMAGE_BUCKET = "meal-images"


@lru_cache(maxsize=1)
def load_meal_catalog() -> dict[str, list[dict[str, Any]]]:
    data = yaml.safe_load(CATALOG_PATH.read_text(encoding="utf-8")) or {}
    return data.get("meal_candidates") or {}


@lru_cache(maxsize=1)
def _by_title() -> dict[str, dict[str, Any]]:
    return {
        item["title"]: item
        for items in load_meal_catalog().values()
        for item in items
        if item.get("title")
    }


def image_path_for(title: str) -> str | None:
    item = _by_title().get(title.strip())
    if not item:
        return None
    value = (item.get("payload") or {}).get("imagePath")
    return value if isinstance(value, str) and value else None


def public_image_url(image_path: str | None, supabase_url: str | None = None) -> str | None:
    if not image_path:
        return None
    if supabase_url is None:
        from app.core.config import get_settings

        supabase_url = get_settings().supabase_url
    base = (supabase_url or "").strip().rstrip("/")
    if not base:
        return None
    encoded_path = quote(image_path.strip().lstrip("/"), safe="/")
    return f"{base}/storage/v1/object/public/{MEAL_IMAGE_BUCKET}/{encoded_path}"


def attach_meal_images(routine: dict[str, Any]) -> dict[str, Any]:
    """카탈로그와 정확히 일치하는 루틴 메뉴에 Storage 객체 경로를 붙인다."""
    meals = []
    for entry in routine.get("meal") or []:
        payload = entry.get("payload") or {}
        image_path = image_path_for(entry.get("title") or "")
        meals.append(
            {**entry, "payload": {**payload, "imagePath": image_path}}
            if image_path
            else entry
        )
    return {**routine, "meal": meals}


def attach_recommendation_image(card: dict[str, Any] | None) -> dict[str, Any] | None:
    if not card:
        return card
    image_path = image_path_for(card.get("title") or "")
    if not image_path:
        return card
    image_url = public_image_url(image_path)
    return {
        **card,
        "imagePath": image_path,
        **({"imageUrl": image_url} if image_url else {}),
    }


def meal_catalog_prompt() -> str:
    """LLM이 사진 없는 임의 메뉴명을 만들지 않도록 끼니별 허용 제목을 제공한다."""
    titles = {
        period: [item["title"] for item in items]
        for period, items in load_meal_catalog().items()
    }
    return json.dumps(titles, ensure_ascii=False)
