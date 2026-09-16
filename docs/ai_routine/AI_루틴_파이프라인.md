# AI 하루 루틴 생성 파이프라인 v2

- 작성일: 2026-09-16 (v2: 파이프라인 A를 팀원 패키지 `pregnancy_rag_supabase_ko`로 교체)
- 작업 디렉토리: `/Users/ella/PLM`
- 관련 기능: W-ROUTINE-001/003, W-MEAL-002, W-HEALTH-001, W-SLEEP-001, W-HOUSE-001
- 관련 문서: `docs/DB_ERD_스키마.md`, `docs/requirements/04_1`, `04_2`

```text
Flutter ─▶ FastAPI ─┬─ Supabase (pregnancy_profiles · daily_conditions · pregnancy_knowledge[pgvector])
                    ├─ Rule Engine (rules.yaml)
                    └─ OpenAI API (질의 임베딩 text-embedding-3-small 1536 + 루틴 생성 json_schema)
                              ▼
                  {meal, household, health, sleep}
```

## v1 → v2 변경

| 항목 | v1 | v2 |
|---|---|---|
| 지식 원본 | 자체 PDF → pypdf | 팀원 패키지: 미국 HHS/OWH 공개 자료 10건 → 영문 청크 75개(staging) |
| 청크·임베딩 | 자체 스크립트, Voyage 1024 | `02_translate_chunk_embed_upload.py`: 번역(OpenAI) → 한국어 재청크(1200/150) → `text-embedding-3-small` 1536 |
| 테이블 | `guideline_documents` + `guideline_chunks(tags jsonb, vector 1024)` | `pregnancy_knowledge(id bigint, category text, week_start, week_end, content, source, embedding vector 1536)` 단일 |
| 검색 | 직접 SQL | RPC `match_pregnancy_knowledge(query_embedding, match_count, filter_week, filter_category)` |
| 태그 | LLM 자동 태깅 jsonb | `category` 키워드 룰(`CATEGORY_RULES`) + 주차 범위 컬럼 |
| `source_ids` | chunk uuid | `pregnancy_knowledge.id` (bigint) |
| 룰 저장 | `routine_rules` 테이블 | `rules.yaml` (모션 파트 방식). `source_ref` FK 삭제 |
| 카테고리명 | `chores` | `household` (ERD·프론트와 통일) |
| LLM 출력 | 자체 스키마 | `routine_items.payload` 모양(ERD §3.2)으로 통일 |
| 백엔드 의존성 | anthropic, pypdf, voyageai | openai 하나 |
| 판단 LLM | Claude | OpenAI (2026-09-16 변경). 임베딩·생성 같은 SDK·같은 키 |
| 환경변수 | `VOYAGE_API_KEY`, `LLM_API_KEY`(Claude) | `LLM_API_KEY` 값 = OpenAI 키. 추가 변수 없음 |

## 1. 파이프라인 A: 지식 적재 (팀원 패키지, 한 번만)

```text
staging.jsonl(영문75) ─▶ ① 번역 ─▶ ② 한국어 재청크 ─▶ ③ 임베딩 ─▶ ④ upsert pregnancy_knowledge
```

| 단계 | 명령 | 완료 확인 |
|---|---|---|
| 0 | `01_create_pregnancy_knowledge.sql` → Supabase SQL Editor 실행 | `select count(*) from pregnancy_knowledge` = 0, 함수 `match_pregnancy_knowledge` 존재 |
| ① | `python 02_... --step translate` | `pregnancy_knowledge_ko.jsonl` 75행, `pregnancy_knowledge_supabase.jsonl` N행(재청크 후, 75 이상) |
| ③ | `--step embed` | `embedding` 길이 1536 |
| ④ | `--step upload` | `select count(*)` = N |

- 위치: 패키지 폴더를 `PLM/tools/rag_ingest/`로 이동. SQL은 `supabase/migrations/20260917000000_pregnancy_knowledge.sql`로 복사(저장소에 스키마 기록).
- 실행 환경: 패키지 자체 `.env`(OPENAI + SUPABASE service role). `requirements.txt` 별도 → `pip install -r tools/rag_ingest/requirements.txt`.
- 데이터 현황(2026-09-16): 번역 0/75, 임베딩 0. 주차 분포: 1~40 54건, 1~12 9건, 산후(null) 6건, 그 외 6건. category 예: `식사·영양 · 활동·운동 · 안전`(26), `약물안전 · 안전`(14), `입덧 · 수면 · 피로`(10).
- 주의: 번역 모델 기본값 `gpt-5.6-luna`는 스크립트 하드코딩. 계정에 없으면 `--translation-model` 옵션으로 변경.

## 2. 파이프라인 B: 루틴 생성 (`POST /api/v1/routine/today`)

| 단계 | 하는 일 | 테이블/외부 | 완료 확인 |
|---|---|---|---|
| ① 입력 | 프로필(주차·다태·알레르기·진단)·오늘 컨디션·예정활동·전일 루틴 완료여부 | `pregnancy_profiles`, `daily_conditions`, `routine_items` | 입력 dict 키 채워짐 |
| ② 룰 | `rules.yaml` 대조 → `{exclude, limit, require}` | 파일 | `waist_pain=7` → `activity:walk` exclude |
| ③ RAG | 컨디션 문장 → OpenAI 임베딩 → RPC `match_pregnancy_knowledge(emb, 5, 주차, category)` ×4 카테고리 | `pregnancy_knowledge` | 카테고리별 청크 ≤5, `source` 있음 |
| ④ 프롬프트 | 시스템(역할·금지·"의료 자문 아님") + ①②③ + 출력 스키마 | - | 길이 로그 |
| ⑤ LLM | OpenAI chat `response_format=json_schema(strict)` | OpenAI | 파싱 성공 |
| ⑥ 검증·폴백 | exclude 항목 제거, 없는 `source_ids` 제거. 실패/10초 → 전일 루틴 → 기본 템플릿 | `daily_routines` | 빈 화면 0건 |
| ⑦ 저장 | `daily_routines` 1행(`source`, `request_payload`, `response`) + `routine_items` N행 | 쓰기 | 홈 4종 카드 |

### 2.1 ③ category 매핑 (RPC `filter_category`는 ilike 부분일치)

| 루틴 카테고리 | filter_category | 비고 |
|---|---|---|
| meal | `식사·영양` | 입덧 심하면 `입덧` 추가 검색 |
| household | `활동·운동` | 부담 회피 근거 |
| health | `통증` / `활동·운동` | 컨디션 최고 통증 부위 문장으로 질의 |
| sleep | `수면` | |

### 2.2 출력 JSON 스키마 (⑤ json_schema strict, ERD payload와 동일 키)

```json
{
  "meal":      [{"item_key":"meal:lunch","title":"...","payload":{"period":"lunch","reasonTitle":"...","reason":"...","evidence":"...","nutritionTags":["철분"],"cautions":[{"title":"...","description":"...","badge":"..."}]},"source_ids":[12]}],
  "household": [{"item_key":"household:laundry","title":"...","payload":{"owner":"self|appliance|partner","applianceAction":"now|reserve|night"},"source_ids":[]}],
  "health":    [{"item_key":"health:waist","title":"...","payload":{"bodyArea":"허리","loads":[{"area":"허리","label":"높음","value":0.8}],"guide":"...","durationMin":5},"source_ids":[]}],
  "sleep":     {"item_key":"sleep:main","title":"...","payload":{"recommendedBedtime":"22:30","environments":[{"type":"temperature","value":"24°C","options":[]}],"tips":["..."]},"source_ids":[]}
}
```

### 2.3 rules.yaml 예시

```yaml
rules:
  - {category: meal,      when: {allergies_any: [갑각류]},         effect: exclude, target: "ingredient:갑각류", reason: 프로필 알레르기}
  - {category: meal,      when: {medical_any: [임신성 당뇨 경계]}, effect: limit,   target: "nutrient:단순당",   reason: 혈당 관리}
  - {category: health,    when: {waist_pain_gte: 4},             effect: exclude, target: "activity:walk",     reason: 허리 통증 심함}
  - {category: household, when: {week_gte: 28, multiple: true},  effect: exclude, target: "chore:heavy_lifting", reason: 쌍태 후기}
  - {category: sleep,     when: {week_gte: 20},                  effect: require, target: "posture:left_side", reason: 좌측위 권장}
```
(컨디션 척도 1~5 → 임계값 4. ERD `daily_conditions` check 1~5 기준)

### 2.4 코드 위치

```text
backend/app/services/routine/
├── inputs.py        ①
├── rules.yaml, rules.py   ②
├── retriever.py     ③ (openai embeddings + supabase.rpc)
├── prompt.py        ④
├── generator.py     ⑤ (LLMService 상속, openai AsyncOpenAI 클라이언트 ③과 공유)
├── fallback.yaml    ⑥ 기본 템플릿
├── repository.py    ⑦
└── service.py       ①~⑦ 조율 + ⑥ validate(exclude 제거·source_ids 검증)·폴백 2단
backend/app/api/v1/routine.py
backend/app/core/config.py   llm_model 추가(기본 gpt-4.1-mini). llm_api_key = OpenAI 키
tools/rag_ingest/            파이프라인 A (팀원 패키지)
supabase/migrations/20260917000000_pregnancy_knowledge.sql
supabase/migrations/20260917000001_routine_tables.sql   (pregnancy_profiles 3~6단계 컬럼, daily_conditions, daily_routines, routine_items)
```

## 3. 만드는 순서

| # | 할 일 | 완료 확인 |
|---|---|---|
| 0-a | 패키지 → `tools/rag_ingest/`, SQL → migrations, 문서 2개 → `docs/` | `git status` |
| 0-b | `requirements.txt`에 `openai==<고정>`. `.env`의 `LLM_API_KEY`가 OpenAI 키인지 확인. `client.models.list()`로 생성 모델명 확정 | import 성공, 모델명 1개 결정 |
| 0-c | 마이그레이션 2건 Supabase 적용 | 테이블 6개 select 성공 |
| 1 | A 실행 (①③④) — OPENAI 키 필요 | `count(*)` = N, RPC 호출 1건 결과 5행 |
| 2 | B ② rules.yaml + rules.py + 테스트 | 통증 4 → walk exclude |
| 3 | B ⑤ OpenAI JSON (룰·RAG 없이) | 4종 키 JSON |
| 4 | B ③④ RAG 연결 | `source_ids` 채워짐 |
| 5 | B ①⑥⑦ + API + `docs/api.md` | 키 빼고 실행 → 폴백 200 |

## 4. 가정 (아니면 말해달라)

| # | 가정 | 대안 |
|---|---|---|
| 1 | 질의 임베딩 = OpenAI `text-embedding-3-small` (적재와 동일 모델 필수). 생성도 OpenAI → SDK 1개 | 생성만 다른 업체 쓰면 SDK 2개 |
| 2 | 번역·임베딩은 팀원 스크립트 그대로, 수정 없음 | category 룰 보강 시 스크립트 수정 후 재실행 |
| 3 | 산후 자료(`week null` 6건)는 RPC 필터에서 자동 포함됨 → 프롬프트에서 "산후 내용 무시" 지시 | RPC에 `and week_start is not null` 추가 |
| 4 | 룰은 yaml | 규칙 20개 초과 시 테이블 |

## 5. NFR

| NFR | 대응 |
|---|---|
| 001 p95 10초 | ⑥ 타임아웃 10초 → 폴백. 임베딩 호출 1회로 묶음(4 질의 batch) |
| 009 키 | `LLM_API_KEY`(OpenAI) backend `.env`만. 팀원 적재 패키지 `.env`는 저장소 밖 |
| 014 최소 전송 | ① 선택 항목만 `request_payload` 기록. 이름·이메일 미전송 |
| 016 폴백 | 전일 → 템플릿 2단 |

## 6. 진행 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-16 | Supabase 마이그레이션 4건 + `20260917000002_grant_service_role.sql` 적용 확인(5테이블·RPC 접근 OK). 이 프로젝트는 service_role 기본 GRANT가 없어 권한 마이그레이션이 필수 |
| 2026-09-16 | 0-a~0-c, 2~5 코드 작성 완료. 테스트 `tests/test_routine_*.py` 19개 통과(가짜 Supabase·OpenAI). 1단계 적재와 3단계 실호출은 OpenAI 크레딧 0(`insufficient_quota`)으로 미실행. `SUPABASE_SERVICE_ROLE_KEY` 비어 있어 마이그레이션 적용·DB 검증 미실행 |

남은 실행 확인 (외부 키 준비 후):
1. ~~마이그레이션 실행~~ 완료(2026-09-16)
2. `tools/rag_ingest/.env`에 `SUPABASE_SERVICE_ROLE_KEY` 채우고 `python 02_translate_chunk_embed_upload.py --step all` → `select count(*) from pregnancy_knowledge` ≥ 75
3. 실제 토큰으로 `POST /api/v1/routine/today` → `source=ai`, `source_ids` 채워짐 확인

