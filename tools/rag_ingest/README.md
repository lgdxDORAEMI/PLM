# 임산부 생활루틴 RAG → Supabase 패키지

## 최종 테이블
pregnancy_knowledge

- id
- category
- week_start
- week_end
- content
- source
- embedding

## 파일
- `pregnancy_knowledge_staging.jsonl`
  - 업로드된 영문 RAG chunk를 Supabase 컬럼 형태로 정리한 중간 데이터
- `01_create_pregnancy_knowledge.sql`
  - pgvector 활성화 + 테이블 + HNSW 인덱스 + 검색 함수 생성
- `02_translate_chunk_embed_upload.py`
  - 영문 원문 정리
  - 한국어 번역
  - 한국어 기준 재-chunking
  - OpenAI embedding 생성
  - Supabase upsert
- `.env.example`
- `requirements.txt`

## 1. Supabase 테이블 생성
Supabase > SQL Editor에서 `01_create_pregnancy_knowledge.sql` 실행

## 2. Python 패키지 설치
```bash
pip install -r requirements.txt
```

## 3. 환경변수
`.env.example`을 `.env`로 복사한 뒤 값 입력

## 4. 전체 실행
```bash
python 02_translate_chunk_embed_upload.py --step all
```

번역만:
```bash
python 02_translate_chunk_embed_upload.py --step translate
```

Embedding만:
```bash
python 02_translate_chunk_embed_upload.py --step embed
```

Supabase 업로드만:
```bash
python 02_translate_chunk_embed_upload.py --step upload
```

## Chunk 기준
한국어 번역 후 다시 분할합니다.

- 최대 약 1,200자
- overlap 약 150자
- 문단/문장 경계를 우선 보존

영문 기준으로 먼저 자른 텍스트를 그대로 embedding하는 것보다,
한국어 서비스에서는 번역 후 한국어 문장 기준으로 다시 나누는 것이 검색 품질 관리에 유리합니다.

## 주수
- 1삼분기: 1~12주
- 2삼분기: 13~28주
- 3삼분기: 29~40주
- 특정 주수 정보가 없는 임신 전반 자료: 1~40주
- 산후 자료: `week_start`, `week_end` = null

## Embedding
기본값:
`text-embedding-3-small` → 1536 dimensions

따라서 SQL 테이블도 `vector(1536)`으로 설정되어 있습니다.

## 보안
`SUPABASE_SERVICE_ROLE_KEY`는 Flutter 앱에 넣으면 안 됩니다.
이 스크립트처럼 서버/로컬 데이터 적재 과정에서만 사용하세요.

실제 앱에서는 Flutter → FastAPI → Supabase 순으로 검색하는 구조를 권장합니다.
