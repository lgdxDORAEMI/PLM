from __future__ import annotations

import os
import json
import re
import time
import argparse
from pathlib import Path
from typing import Iterable

from dotenv import load_dotenv
from openai import OpenAI
from supabase import create_client

BASE = Path(__file__).resolve().parent
STAGING = BASE / "pregnancy_knowledge_staging.jsonl"
TRANSLATED = BASE / "pregnancy_knowledge_ko.jsonl"
FINAL = BASE / "pregnancy_knowledge_supabase.jsonl"

# 한국어 RAG용 권장값: 의미 단위를 너무 잘게 쪼개지 않도록 900~1,400자 정도 사용
DEFAULT_MAX_CHARS = 1200
DEFAULT_OVERLAP = 150

CATEGORY_RULES = [
    ("입덧", ["입덧", "구역", "구토", "메스꺼움"]),
    ("수면", ["수면", "잠", "불면", "피로", "낮잠"]),
    ("통증", ["통증", "허리", "골반", "경련", "쥐"]),
    ("소화", ["소화", "속쓰림", "변비", "치질"]),
    ("식사·영양", ["식사", "영양", "칼로리", "체중", "식품"]),
    ("활동·운동", ["운동", "활동", "걷기", "스트레칭"]),
    ("약물안전", ["약", "의약품", "복용"]),
    ("위험신호", ["즉시", "진료", "출혈", "응급", "전자간증", "위험"]),
]

def read_jsonl(path: Path):
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)

def write_jsonl(path: Path, rows):
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

def clean_english_source(text: str) -> str:
    # 크롤링 시 섞인 UI/네비게이션 표현 제거
    blacklist = [
        r"Find a Health Center",
        r"Enter a city, ZIP code.*?(?=\n|$)",
        r"Subscribe",
        r"To receive email updates",
    ]
    for pat in blacklist:
        text = re.sub(pat, "", text, flags=re.I)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

def translate_to_korean(client: OpenAI, text: str, model: str) -> str:
    prompt = f"""
다음은 미국 정부의 임신·산모 건강 안내 원문이다.
한국어 RAG 데이터로 사용할 수 있도록 정확하게 번역하라.

규칙:
- 의학적 내용을 임의로 추가하거나 삭제하지 않는다.
- 원문의 경고, 조건, 수치, 주수는 반드시 보존한다.
- 자연스러운 한국어로 번역하되 요약하지 않는다.
- 메뉴, 구독, 검색창 등 웹사이트 UI 문구가 남아 있으면 제외한다.
- 미국 단위가 나오면 원 단위를 보존하고 괄호 안에 한국에서 이해하기 쉬운 환산을 함께 적을 수 있다.
- 결과에는 번역문만 출력한다.

원문:
{text}
""".strip()

    response = client.responses.create(
        model=model,
        input=prompt,
    )
    return response.output_text.strip()

def split_sentences_ko(text: str):
    # 문단 우선, 너무 긴 문단만 문장 단위 분리
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    out = []
    for p in paras:
        if len(p) <= 700:
            out.append(p)
        else:
            sentences = re.split(r"(?<=[.!?다요])\s+", p)
            out.extend([s.strip() for s in sentences if s.strip()])
    return out

def chunk_korean(text: str, max_chars: int, overlap_chars: int):
    units = split_sentences_ko(text)
    chunks = []
    buf = ""

    for unit in units:
        candidate = f"{buf}\n\n{unit}".strip() if buf else unit
        if len(candidate) <= max_chars:
            buf = candidate
            continue

        if buf:
            chunks.append(buf)
            tail = buf[-overlap_chars:] if overlap_chars else ""
            buf = f"{tail}\n\n{unit}".strip()
        else:
            start = 0
            while start < len(unit):
                end = min(start + max_chars, len(unit))
                chunks.append(unit[start:end])
                if end == len(unit):
                    buf = ""
                    break
                start = max(end - overlap_chars, start + 1)

    if buf:
        chunks.append(buf)
    return [c.strip() for c in chunks if c.strip()]

def refine_category(base_category: str, content: str) -> str:
    detected = []
    for label, keys in CATEGORY_RULES:
        if any(k in content for k in keys):
            detected.append(label)
    if detected:
        return " · ".join(dict.fromkeys(detected[:3]))
    return base_category

def translate_and_rechunk(args):
    load_dotenv(BASE / ".env")
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY가 없습니다. .env 파일에 입력하세요.")

    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    translated_docs = []

    rows = list(read_jsonl(STAGING))
    for idx, row in enumerate(rows, start=1):
        print(f"[translate {idx}/{len(rows)}] {row['_meta']['chunk_id']}")
        cleaned = clean_english_source(row["content_en"])
        ko = translate_to_korean(client, cleaned, args.translation_model)

        translated_docs.append({
            **row,
            "content": ko,
        })
        time.sleep(args.sleep)

    write_jsonl(TRANSLATED, translated_docs)

    # 번역 이후 한국어 기준으로 다시 chunking
    final = []
    new_id = 1
    for row in translated_docs:
        chunks = chunk_korean(row["content"], args.max_chars, args.overlap)
        for chunk_index, chunk in enumerate(chunks):
            final.append({
                "id": new_id,
                "category": refine_category(row["category"], chunk),
                "week_start": row["week_start"],
                "week_end": row["week_end"],
                "content": chunk,
                "source": row["source"],
                "embedding": None,
                "_meta": {
                    **row["_meta"],
                    "ko_chunk_index": chunk_index,
                }
            })
            new_id += 1

    write_jsonl(FINAL, final)
    print(f"완료: {FINAL} / {len(final)} chunks")

def add_embeddings(args):
    load_dotenv(BASE / ".env")
    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY가 없습니다. .env 파일에 입력하세요.")
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    rows = list(read_jsonl(FINAL))
    texts = [r["content"] for r in rows]

    for start in range(0, len(texts), args.embedding_batch):
        batch = texts[start:start + args.embedding_batch]
        print(f"[embedding] {start+1}~{min(start+len(batch), len(texts))}/{len(texts)}")
        res = client.embeddings.create(
            model=args.embedding_model,
            input=batch,
        )
        for offset, item in enumerate(res.data):
            rows[start + offset]["embedding"] = item.embedding

    write_jsonl(FINAL, rows)
    print(f"Embedding 완료: {FINAL}")

def upload_supabase(args):
    load_dotenv(BASE / ".env")
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        raise RuntimeError("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY가 없습니다.")

    sb = create_client(url, key)
    rows = list(read_jsonl(FINAL))

    payload = []
    for r in rows:
        if r.get("embedding") is None:
            raise RuntimeError("embedding이 비어 있습니다. 먼저 --step embed를 실행하세요.")
        payload.append({
            "id": r["id"],
            "category": r["category"],
            "week_start": r["week_start"],
            "week_end": r["week_end"],
            "content": r["content"],
            "source": r["source"],
            "embedding": r["embedding"],
        })

    for start in range(0, len(payload), args.supabase_batch):
        batch = payload[start:start + args.supabase_batch]
        print(f"[supabase] {start+1}~{min(start+len(batch), len(payload))}/{len(payload)}")
        sb.table("pregnancy_knowledge").upsert(batch, on_conflict="id").execute()

    print("Supabase 업로드 완료")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--step", choices=["translate", "embed", "upload", "all"], default="all")
    parser.add_argument("--translation-model", default="gpt-5.6-luna")
    parser.add_argument("--embedding-model", default="text-embedding-3-small")
    parser.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS)
    parser.add_argument("--overlap", type=int, default=DEFAULT_OVERLAP)
    parser.add_argument("--embedding-batch", type=int, default=50)
    parser.add_argument("--supabase-batch", type=int, default=100)
    parser.add_argument("--sleep", type=float, default=0.05)
    args = parser.parse_args()

    if args.step in ("translate", "all"):
        translate_and_rechunk(args)
    if args.step in ("embed", "all"):
        add_embeddings(args)
    if args.step in ("upload", "all"):
        upload_supabase(args)

if __name__ == "__main__":
    main()
