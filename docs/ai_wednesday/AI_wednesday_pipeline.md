# 웬즈데이 AI (AI 하루 루틴 생성 파이프라인) v3

- 작성일: 2026-09-16 / 갱신: 2026-09-17 (v3: 카테고리별 4회 동시 생성, 금지어 검증 범위 수정, 실테스트 완료)
- 이름: 2026-09-16(수)에 만들어 "웬즈데이 AI". 코드 식별자는 `routine` 그대로(`app/services/routine/`, `/api/v1/routine/today`)
- 작업 디렉토리: `/Users/ella/PLM`
- 관련 기능: FUC-W-HOME-001(생성·표시), FUC-W-CALLBACK-001(실패·폴백), FUC-W-COND-001~004(컨디션·재생성), FUC-W-TASK-001, FUC-W-MEAL-002, FUC-W-HEALTH-001, FUC-W-SLEEP-001, FUC-W-HOUSE-001
- 관련 문서: `docs/api.md`(API 계약·payload 표), `docs/서비스흐름도/02_AI하루루틴생성.mmd`, `docs/backend/TARGET_DB_SCHEMA.md`, `supabase/migrations/`, `docs/requirements/04_1`, `04_2`

```text
Flutter ─▶ FastAPI ─┬─ Supabase (pregnancy_profiles · daily_conditions · pregnancy_knowledge[pgvector])
                    ├─ Rule Engine (rules.yaml)
                    └─ OpenAI API (질의 임베딩 text-embedding-3-small 1536
                                   + 루틴 생성 json_schema × 4 카테고리 동시 호출)
                              ▼
                  {meal, household, health, sleep}
```

## v1 → v2 → v3 변경

| 항목 | v1 | v2 (09-16) | v3 (09-17) |
|---|---|---|---|
| 지식 원본 | 자체 PDF → pypdf | 팀원 패키지: HHS/OWH 공개 자료 10건 → 영문 청크 75개 | 동일. 적재 완료 88청크 |
| 청크·임베딩 | 자체 스크립트, Voyage 1024 | 번역(OpenAI) → 한국어 재청크(1200/150) → `text-embedding-3-small` 1536 | 동일 |
| 테이블 | `guideline_documents` + `guideline_chunks` | `pregnancy_knowledge` 단일 | 동일 |
| 검색 | 직접 SQL | RPC `match_pregnancy_knowledge` | 동일 |
| 룰 저장 | `routine_rules` 테이블 | `rules.yaml` | exclude 규칙에 `keywords`(메뉴 단어) 추가 |
| 카테고리명 | `chores` | `household` | 동일 |
| LLM 호출 | - | 4종 한 번에 1회 | **카테고리별 4회 동시**(`asyncio.gather`) |
| 금지어 검증 | - | 항목 JSON 전체 부분일치 | **`title`·`nutritionTags`만** 검사 |
| 판단 LLM | Claude | OpenAI `gpt-4.1-mini` | 동일 |
| 백엔드 의존성 | anthropic, pypdf, voyageai | openai 하나 | 동일 |

## 1. 파이프라인 A: 지식 적재 (팀원 패키지, 한 번만)

```text
staging.jsonl(영문75) ─▶ ① 번역 ─▶ ② 한국어 재청크 ─▶ ③ 임베딩 ─▶ ④ upsert pregnancy_knowledge
```

| 단계 | 명령 | 완료 확인 |
|---|---|---|
| 0 | `01_create_pregnancy_knowledge.sql` (= `supabase/migrations/20260917000000_pregnancy_knowledge.sql`) | 테이블·함수 존재 |
| 전체 | `cd tools/rag_ingest && ../../backend/.venv/bin/python 02_translate_chunk_embed_upload.py --step all` | `select count(*) from pregnancy_knowledge` ≥ 75 |

- 실행 환경: `tools/rag_ingest/.env`(OPENAI + SUPABASE service role, gitignore).
- **적재 결과(2026-09-17)**: 번역 75 → 재청크 **88청크**, 임베딩 1536차원, 업로드 88행. 소요 약 20분(번역 모델 `gpt-5.6-luna` 추론형이라 느림).
- category 분포(청크에 복수 태그): 식사·영양 45, 약물안전 44, 위험신호 33, 통증 19, 활동·운동 18, 수면 15, 소화 13, 입덧 11, 기타 각 1.
- 중간 산출물 `pregnancy_knowledge_ko.jsonl`, `pregnancy_knowledge_supabase.jsonl`은 커밋하지 않는다.
- 비용: OpenAI 대시보드 기준 9/17까지 누적 $0.10. 대부분 번역(`gpt-5.6-luna`, 추론 토큰이 출력으로 과금). 사전 견적 $0.06은 과소 추정이었다.

## 2. 파이프라인 B: 루틴 생성 (`POST /api/v1/routine/today`)

| 단계 | 하는 일 | 테이블/외부 | 완료 확인 |
|---|---|---|---|
| ① 입력 | 프로필(주차·다태·알레르기·진단)·오늘 컨디션·예정활동 | `pregnancy_profiles`, `daily_conditions` | 입력 dict 키 채워짐. 없으면 409 |
| ② 룰 | `rules.yaml` 16규칙 대조 → `{exclude, limit, require}` (+exclude는 `keywords`) | 파일 | 허리 통증 4 → `activity:walk` exclude |
| ③ RAG | 카테고리별 질의 문장 4개 → 임베딩 1회 batch → RPC `match_pregnancy_knowledge(emb, 5, 주차, category)` ×4 병렬 | `pregnancy_knowledge` | 카테고리별 청크 ≤5 |
| ④ 프롬프트 | 카테고리마다: 시스템 + facts + **그 카테고리 규칙·참고 문단만** + 카테고리 스키마 | - | 입력 약 2.3k~3.4k 토큰/호출 |
| ⑤ LLM | OpenAI chat `json_schema(strict)` **4회 동시**. 하나라도 실패하면 예외 | OpenAI | 4종 파싱 성공 |
| ⑥ 검증·폴백 | 금지어가 `title`·`nutritionTags`에 있는 항목 제거, 없는 `source_ids` 제거. 실패/9.5초 → 전일 루틴 → 기본 템플릿 | `daily_routines` | 빈 화면 0건 |
| ⑦ 저장 | `daily_routines` 1행(`source`, `prompt_version`, `request_payload`, `response`) + `routine_items` N행 | 쓰기 | 홈 4종 카드 |

### 2.1 ③ category 매핑 (RPC `filter_category`는 ilike 부분일치)

| 루틴 카테고리 | filter_category |
|---|---|
| meal | `식사·영양` |
| household | `활동·운동` |
| health | `통증` |
| sleep | `수면` |

### 2.2 출력 JSON 스키마

- 기준 코드: `backend/app/services/routine/prompt.py` `ROUTINE_SCHEMA`, 카테고리별은 `category_schema(category)` → `{category: ...}`.
- payload 필드 표는 `docs/api.md` "AI 하루 루틴" 절이 계약 원본.
- 버전: `PROMPT_VERSION = "2026-09-17.1"` (`daily_routines.prompt_version`에 저장).

```json
{
  "meal":      [{"item_key":"...","title":"...","payload":{"period":"breakfast|lunch|dinner|snack","reasonTitle":"...","reason":"...","evidence":"...","nutritionTags":["철분"],"cautions":[{"title":"...","description":"...","badge":"..."}]},"source_ids":[12]}],
  "household": [{"item_key":"...","title":"...","payload":{"owner":"self|appliance|partner","applianceAction":"now|reserve|night|none","reason":"..."},"source_ids":[]}],
  "health":    [{"item_key":"...","title":"...","payload":{"bodyArea":"허리","loads":[{"area":"허리","label":"높음","value":0.8}],"guide":"...","durationMin":5,"reason":"..."},"source_ids":[]}],
  "sleep":     {"item_key":"...","title":"...","payload":{"recommendedBedtime":"22:30","environments":[{"type":"temperature","value":"24°C","options":[]}],"tips":["..."],"reason":"..."},"source_ids":[]}
}
```

### 2.3 rules.yaml 형식

```yaml
rules:
  - category: meal
    when: {allergies_any: [갑각류]}
    effect: exclude
    target: "ingredient:갑각류"
    keywords: [새우, 꽃게, 대게, 게살, 킹크랩, 랍스터, 가재, 크릴]   # 검증(⑥)이 title·nutritionTags에서 찾는 단어
    reason: 프로필 알레르기(갑각류)
  - {category: health, when: {waist_pain_gte: 4}, effect: exclude, target: "activity:walk", reason: 허리 통증 심함}
  - {category: sleep,  when: {week_gte: 20},      effect: require, target: "posture:left_side", reason: 20주 이후 좌측위 권장}
```

- `keywords` 있는 규칙: 알레르기 5종(갑각류·견과류·우유·계란·밀), `food:기름진 음식`.
- 한계: `keywords`에 없는 메뉴명(예: 해물찜)은 못 거른다 → 누락이 보이면 단어 추가. 코드형 target(`activity:walk`)은 한국어 제목과 안 맞아 `keywords` 없으면 검증에서 안 걸림(프롬프트 규칙으로만 지시).

### 2.4 코드 위치

```text
backend/app/services/routine/
├── inputs.py        ①
├── rules.yaml, rules.py   ② (keywords 전달)
├── retriever.py     ③ (임베딩 1회 batch + RPC 4회 스레드 병렬)
├── prompt.py        ④ SYSTEM_PROMPT, ROUTINE_SCHEMA, category_schema, build_user_prompt(category=)
├── generator.py     ⑤ generate_category(1개) / generate_routine(4개 gather)
├── fallback.yaml    ⑥ 기본 템플릿
├── repository.py    ⑦
└── service.py       ①~⑦ 조율 + ⑥ validate·폴백 2단, TOTAL_TIMEOUT_SEC=9.5
backend/app/api/v1/routine.py
backend/tests/test_routine_{prompt,rules,service}.py
tools/rag_ingest/            파이프라인 A (팀원 패키지)
supabase/migrations/20260917000000_pregnancy_knowledge.sql
supabase/migrations/20260917000001_routine_tables.sql
supabase/migrations/20260917000002_grant_service_role.sql
```

## 3. 만드는 순서 (v2 기준, 모두 완료)

| # | 할 일 | 상태 |
|---|---|---|
| 0-a~0-c | 패키지 이동, openai 의존성, 마이그레이션 적용 | 완료 09-16 |
| 1 | A 적재 | 완료 09-17 (88행) |
| 2~5 | B 룰·생성·RAG·검증·저장·API | 완료 09-16 |
| 6 | 실호출 검증 | 완료 09-17 (3회 `source=ai`) |

## 4. 가정 (아니면 말해달라)

| # | 가정 | 대안 |
|---|---|---|
| 1 | 질의 임베딩 = 적재와 같은 `text-embedding-3-small` | 모델 바꾸면 재적재 필수 |
| 2 | 산후 자료(`week null`)는 RPC에서 포함 → 프롬프트에서 "산후 내용 무시" | RPC에 `week_start is not null` 추가 |
| 3 | 룰은 yaml | 규칙 20개 초과 시 테이블 |
| 4 | 4개 카테고리 중 하나라도 실패하면 4종 전체 폴백 | 실패 카테고리만 템플릿(부분 폴백). `daily_routines.source` 의미·check 변경 필요해 보류 |

## 5. NFR

| NFR | 기준 | 대응·실측 |
|---|---|---|
| 001 응답시간 | **p50 ≤ 5초, p95 ≤ 10초** | 4회 동시 생성. 실측 3회 5.76 / 6.22 / 4.99초 → p95 충족, **p50 미달 가능(중간값 5.76초)** |
| 009 키 | backend `.env`만 | `LLM_API_KEY`(OpenAI). 적재 패키지 `.env`는 gitignore |
| 014 최소 전송 | 필요한 항목만 | `LLM_FACT_KEYS`만 전송·`request_payload` 기록 |
| 016 폴백 | 빈 화면 0건 | 전일 → 템플릿 2단 |

### 5.1 비용 (gpt-4.1-mini: 입력 $0.40 / 출력 $1.60 per 1M, 공식 가격표)

| 방식 | 입력 토큰 | 출력 토큰 | 호출당 |
|---|---|---|---|
| v2 1회 호출 (실측 1회) | 9,621 | 658 | $0.0049 |
| v3 4회 동시 (실측 3회 평균) | 11,121 | 1,421 | **약 $0.0067** |

사용자 100명 × 30일 × 하루 1회 ≈ $20. 재생성(FUC-W-COND-003/004) 횟수만큼 증가.

## 6. 진행 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-16 | Supabase 마이그레이션 5건 적용(`20260917000002_grant_service_role.sql` 필수: service_role 기본 GRANT 없음). 코드 ①~⑦·API 완료. 적재·실호출은 OpenAI 크레딧 0으로 미실행 |
| 2026-09-17 | 적재 완료(88행). 실호출 1회 `source=ai` 8.39초 |
| 2026-09-17 | **버그**: 갑각류 알레르기·입덧 4 조건에서 식단 0건. 원인 = 검증이 설명문("기름진 음식과 갑각류를 피하면서")의 금지어까지 걸러 전부 삭제. 수정 = 이름(`title`·`nutritionTags`)만 검사 + `keywords` |
| 2026-09-17 | **성능**: 1회 생성 8.4~8.6초로 3회 중 2회 9.5초 타임아웃 폴백. 수정 = 카테고리별 4회 동시 생성. 재실측 3회 모두 `source=ai`, 4.99~6.22초 |
| 2026-09-17 | 테스트 56개 통과(회귀 테스트: 설명문 금지어 유지, 4회 분리 호출·카테고리별 규칙 분리, 카테고리 스키마 strict) |
| 2026-09-17 | 문서: `docs/ai_routine/AI_루틴_파이프라인.md` → `docs/ai_wednesday/AI_wednesday_pipeline.md` 이름 변경. `DB_ERD_스키마.md`·`04_3_개발순서.md` 삭제(팀 합의), payload 표는 `docs/api.md`로 이동 |

## 7. 남은 것

### 7.1 요구사항 변경 반영 (2026-09-17 흐름도 `02_AI하루루틴생성.mmd`, 04_1 개정)

| # | 요구 | 현재 | 할 일 |
|---|---|---|---|
| R1 | 확정 후 컨디션 재입력 = 기존 루틴 덮어쓰지 않고 새 루틴(FUC-W-COND-004), 날짜별 Daily 리포트 1개(NFR-028) | `daily_routines` unique(user_id, date) 덮어쓰기, 확정 상태 없음 | 버전별 행 누적 + 확정 상태 저장. `TARGET_DB_SCHEMA.md`와 맞춰 마이그레이션 |
| R2 | 확정 전 수정 = 루틴 재생성 + 남편 알림(FUC-W-COND-003, FUC-H-NOTI-002) | 재생성 신호 없음, 완료 체크 유실 | 이전 버전 diff(`item_key` 기준), 완료 체크 이어받기, 응답에 `revision`·`is_regeneration`·`change_summary` |
| R3 | AI 실패 시 실패 화면(W-CALLBACK-001) + 다시 시도 → 연속 실패 시 폴백 | 실패 즉시 폴백 저장 후 201 | 최소: `docs/api.md`에 "`source != ai`면 실패 안내 가능" 명시. 백엔드 동작 변경 여부 결정 |
| R4 | 웰컴 카드 '오늘의 팁' 1개 AI 개인화(FUC-W-HOME-001) | 출력 4종뿐 | 출력 스키마에 추가 여부 결정 |
| R5 | 입력에 전일 활동·홈캠 데이터 | 미포함 | 모션 요약 연결(모션 팀과 계약) |

### 7.2 알려진 문제

| # | 문제 | 근거 |
|---|---|---|
| K1 | p50 5초 미달 가능 | 실측 중간값 5.76초(3회). 출력 분량 제한 또는 모델 검토 |
| K2 | AI가 만든 `item_key`가 `breakfast_1` 형식(설계 `meal:lunch`) | 09-17 실호출 원본. R2 diff 전에 키 규칙 고정 필요 |
| K3 | `daily_conditions.sleep_quality` 컬럼·`LLM_FACT_KEYS`에 수면 값이 남아 있음 | 04_1 FUC-W-COND-001 입력 4종에 수면 없음 |
| K4 | 컨디션 저장 API 없음 → 실제 앱에선 항상 409 | `PUT /api/v1/condition/today` 계약 필요, 활동 코드표 9종(프론트 한글 라벨 vs 백엔드 코드) 함께 확정 |
| K5 | 날짜 기준 모션=UTC, 웬즈데이=KST | 통합 시 전일 요약 어긋남 |
| K6 | 코드·문서 주석의 옛 ID `W-ROUTINE-001/003` | `backend/README.md`, `api/v1/routine.py`, `service.py`, `fallback.yaml`, `docs/api.md`, migration 주석 → `W-HOME-001`/`W-CALLBACK-001` |
