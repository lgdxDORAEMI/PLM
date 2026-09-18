# AI 하루 루틴 생성 파이프라인 v2 (웬즈데이 AI)

- 작성일: 2026-09-16 (v2: 파이프라인 A를 팀원 패키지 `pregnancy_rag_supabase_ko`로 교체) / 진행 표시 갱신: 2026-09-18
- 표기: ~~취소선~~ = 완료된 부분. 작업이 끝나 커밋할 때 취소선을 지운다.
- 작업 디렉토리: `/Users/ella/PLM`
- 관련 기능: W-HOME-001(구 W-ROUTINE-001), W-CALLBACK-001(구 W-ROUTINE-003), W-MEAL-002, W-HEALTH-001, W-SLEEP-001, W-HOUSE-001
- 관련 문서: `docs/api.md`, `docs/backend/TARGET_DB_SCHEMA.md`, `docs/서비스흐름도/02_AI하루루틴생성.mmd`, `docs/requirements/04_1`, `04_2`

```text
Flutter ─▶ FastAPI ─┬─ Supabase (pregnancy_profiles · daily_conditions · pregnancy_knowledge[pgvector])
                    ├─ Rule Engine (rules.yaml)
                    └─ OpenAI API (질의 임베딩 text-embedding-3-small 1536 + 루틴 생성 json_schema ×4 카테고리)
                              ▼
                  {meal, household, health, sleep}
```

## v1 → v2 변경

| 항목 | v1 | v2 |
|---|---|---|
| 지식 원본 | 자체 PDF → pypdf | ~~팀원 패키지: 미국 HHS/OWH 공개 자료 10건 → 영문 청크 75개(staging)~~ |
| 청크·임베딩 | 자체 스크립트, Voyage 1024 | ~~`02_translate_chunk_embed_upload.py`: 번역(OpenAI) → 한국어 재청크(1200/150) → `text-embedding-3-small` 1536~~ |
| 테이블 | `guideline_documents` + `guideline_chunks(tags jsonb, vector 1024)` | ~~`pregnancy_knowledge(id bigint, category text, week_start, week_end, content, source, embedding vector 1536)` 단일~~ |
| 검색 | 직접 SQL | ~~RPC `match_pregnancy_knowledge(query_embedding, match_count, filter_week, filter_category)`~~ |
| 태그 | LLM 자동 태깅 jsonb | ~~`category` 키워드 룰(`CATEGORY_RULES`) + 주차 범위 컬럼~~ |
| `source_ids` | chunk uuid | ~~`pregnancy_knowledge.id` (bigint)~~ |
| 룰 저장 | `routine_rules` 테이블 | ~~`rules.yaml` (모션 파트 방식). `source_ref` FK 삭제~~ |
| 카테고리명 | `chores` | ~~`household` (DB·프론트와 통일)~~ |
| LLM 출력 | 자체 스키마 | ~~`routine_items.payload` 모양(`docs/api.md` payload 표)으로 통일~~ |
| 백엔드 의존성 | anthropic, pypdf, voyageai | ~~openai 하나~~ |
| 판단 LLM | Claude | ~~OpenAI (2026-09-16 변경). 임베딩·생성 같은 SDK·같은 키~~ |
| 환경변수 | `VOYAGE_API_KEY`, `LLM_API_KEY`(Claude) | ~~`LLM_API_KEY` 값 = OpenAI 키. 추가 변수 없음~~ |

## 1. 파이프라인 A: 지식 적재 (팀원 패키지, 한 번만)

```text
staging.jsonl(영문75) ─▶ ① 번역 ─▶ ② 한국어 재청크 ─▶ ③ 임베딩 ─▶ ④ upsert pregnancy_knowledge
```

| 단계 | 명령 | 완료 확인 |
|---|---|---|
| 0 | ~~`01_create_pregnancy_knowledge.sql` → Supabase SQL Editor 실행~~ | ~~함수 `match_pregnancy_knowledge` 존재~~ |
| ① | ~~`python 02_... --step translate`~~ | ~~`pregnancy_knowledge_ko.jsonl` 75행, `pregnancy_knowledge_supabase.jsonl` 88행(재청크 후)~~ |
| ③ | ~~`--step embed`~~ | ~~`embedding` 길이 1536~~ |
| ④ | ~~`--step upload`~~ | ~~`select count(*)` = 88~~ |

- ~~위치: 패키지 폴더를 `PLM/tools/rag_ingest/`로 이동. SQL은 `supabase/migrations/20260917000000_pregnancy_knowledge.sql`로 복사(저장소에 스키마 기록).~~
- ~~실행 환경: 패키지 자체 `.env`(OPENAI + SUPABASE service role). `requirements.txt` 별도 → `pip install -r tools/rag_ingest/requirements.txt`.~~
- ~~데이터 현황(2026-09-17 실행 결과): 번역 75/75, 재청크 88, 임베딩 88, 업로드 88행. 소요 약 20분. 결과 jsonl 2개는 09-17에 커밋.~~
- ~~주의: 번역 모델 기본값 `gpt-5.6-luna`는 스크립트 하드코딩. 계정에 없으면 `--translation-model` 옵션으로 변경.~~

## 2. 파이프라인 B: 루틴 생성 (`POST /api/v1/routine/today`)

| 단계 | 하는 일 | 테이블/외부 | 완료 확인 |
|---|---|---|---|
| ① 입력 | ~~프로필(주차·다태·알레르기·진단)·오늘 컨디션·예정활동~~ / 전일 루틴·홈캠은 미연결(R5) | `pregnancy_profiles`, `daily_conditions` | ~~입력 dict 키 채워짐~~ |
| ② 룰 | ~~`rules.yaml` 대조 → `{exclude, limit, require}`. exclude는 `keywords`(메뉴 단어) 포함~~ | 파일 | ~~통증 4 → `activity:walk` exclude~~ |
| ③ RAG | ~~컨디션 문장 → OpenAI 임베딩 1회 batch → RPC `match_pregnancy_knowledge(emb, 5, 주차, category)` ×4 카테고리~~ | `pregnancy_knowledge` | ~~카테고리별 청크 ≤5, `source` 있음~~ |
| ④ 프롬프트 | ~~시스템(역할·금지·"의료 자문 아님") + ①②③ + 출력 스키마. 카테고리별로 그 카테고리 규칙·문단만~~ | - | ~~입력 약 2.3k~3.4k 토큰/호출~~ |
| ⑤ LLM | ~~OpenAI chat `response_format=json_schema(strict)` — 카테고리별 4회 동시 호출~~ | OpenAI | ~~파싱 성공~~ |
| ⑥ 검증·폴백 | ~~exclude 항목 제거(`title`·`nutritionTags`만 검사), 없는 `source_ids` 제거. 실패/9.5초 → 전일 루틴 → 기본 템플릿~~ | `daily_routines` | ~~빈 화면 0건~~ |
| ⑦ 저장 | ~~`daily_routines` 1행(`source`, `prompt_version`, `request_payload`, `response`) + `routine_items` N행~~ | 쓰기 | ~~홈 4종 카드~~ |

### 2.1 ③ category 매핑 (RPC `filter_category`는 ilike 부분일치)

| 루틴 카테고리 | filter_category | 비고 |
|---|---|---|
| meal | ~~`식사·영양`~~ | 입덧 심하면 `입덧` 추가 검색(미적용) |
| household | ~~`활동·운동`~~ | ~~부담 회피 근거~~ |
| health | ~~`통증`~~ | ~~컨디션 최고 통증 부위 문장으로 질의~~ |
| sleep | ~~`수면`~~ | |

### 2.2 출력 JSON 스키마 (⑤ json_schema strict, `docs/api.md` payload와 동일 키)

~~`item_key`는 스키마 값 목록으로 고정(09-18): meal 4종, health 6종(`waist|pelvis|leg|wrist|whole|rest`), sleep 1종. household는 활동 코드표 미확정이라 자유 문자열 + 코드가 `household:` 접두사 보정.~~

```json
{
  "meal":      [{"item_key":"meal:lunch","title":"...","payload":{"period":"lunch","reasonTitle":"...","reason":"...","evidence":"...","nutritionTags":["철분"],"cautions":[{"title":"...","description":"...","badge":"..."}]},"source_ids":[12]}],
  "household": [{"item_key":"household:laundry","title":"...","payload":{"owner":"self|appliance|partner","applianceAction":"now|reserve|night|none","reason":"..."},"source_ids":[]}],
  "health":    [{"item_key":"health:waist","title":"...","payload":{"bodyArea":"허리","loads":[{"area":"허리","label":"높음","value":0.8}],"guide":"...","durationMin":5,"reason":"..."},"source_ids":[]}],
  "sleep":     {"item_key":"sleep:main","title":"...","payload":{"recommendedBedtime":"22:30","environments":[{"type":"temperature","value":"24°C","options":[]}],"tips":["..."],"reason":"..."},"source_ids":[]}
}
```

### 2.3 rules.yaml 예시

```yaml
rules:
  - {category: meal,      when: {allergies_any: [갑각류]},         effect: exclude, target: "ingredient:갑각류", keywords: [새우, 꽃게, 게살], reason: 프로필 알레르기}
  - {category: meal,      when: {medical_any: [임신성 당뇨 경계]}, effect: limit,   target: "nutrient:단순당",   reason: 혈당 관리}
  - {category: health,    when: {waist_pain_gte: 4},             effect: exclude, target: "activity:walk",     reason: 허리 통증 심함}
  - {category: household, when: {week_gte: 28, multiple: true},  effect: exclude, target: "chore:heavy_lifting", reason: 쌍태 후기}
  - {category: sleep,     when: {week_gte: 20},                  effect: require, target: "posture:left_side", reason: 좌측위 권장}
```
(컨디션 척도 1~5 → 임계값 4. migration `daily_conditions` check 1~5 기준. 현재 규칙 16개)

### 2.4 코드 위치

```text
backend/app/services/routine/
├── inputs.py        ①
├── rules.yaml, rules.py   ② (keywords 전달)
├── retriever.py     ③ (openai embeddings + supabase.rpc)
├── prompt.py        ④ (ROUTINE_SCHEMA, category_schema, item_key 값 목록)
├── generator.py     ⑤ (LLMService 상속, generate_category / generate_routine 4회 gather)
├── fallback.yaml    ⑥ 기본 템플릿
├── diff.py          재생성 비교(diff_items·carry_over, S2)
├── repository.py    ⑦ (S3: revision 행 추가, routine_items 제자리 갱신, revision 충돌 1회 재시도)
└── service.py       ①~⑦ 조율 + ⑥ validate(exclude 제거·source_ids 검증)·폴백 2단, _normalize_item_keys
backend/app/api/v1/routine.py
backend/app/core/config.py   llm_model 추가(기본 gpt-4.1-mini). llm_api_key = OpenAI 키
tools/rag_ingest/            파이프라인 A (팀원 패키지)
supabase/migrations/20260917000000_pregnancy_knowledge.sql
supabase/migrations/20260917000001_routine_tables.sql   (pregnancy_profiles 3~6단계 컬럼, daily_conditions, daily_routines, routine_items)
supabase/migrations/20260917000002_grant_service_role.sql
supabase/migrations/20260918000000_daily_experience_routine_versions.sql   (S3, 적용 완료 09-18)
```

## 3. 만드는 순서

| # | 할 일 | 완료 확인 |
|---|---|---|
| 0-a | ~~패키지 → `tools/rag_ingest/`, SQL → migrations, 문서 2개 → `docs/`~~ | ~~`git status`~~ |
| 0-b | ~~`requirements.txt`에 `openai==<고정>`. `.env`의 `LLM_API_KEY`가 OpenAI 키인지 확인~~ | ~~import 성공, 모델명 1개 결정~~ |
| 0-c | ~~마이그레이션 2건 Supabase 적용~~ | ~~테이블 6개 select 성공~~ |
| 1 | ~~A 실행 (①③④) — OPENAI 키 필요~~ | ~~`count(*)` = 88, RPC 결과 5행~~ |
| 2 | ~~B ② rules.yaml + rules.py + 테스트~~ | ~~통증 4 → walk exclude~~ |
| 3 | ~~B ⑤ OpenAI JSON (룰·RAG 없이)~~ | ~~4종 키 JSON~~ |
| 4 | ~~B ③④ RAG 연결~~ | ~~`source_ids` 채워짐~~ |
| 5 | ~~B ①⑥⑦ + API + `docs/api.md`~~ | ~~키 빼고 실행 → 폴백 200~~ |
| 6 | ~~실호출 검증 + 식단 0건 버그 수정 + 4회 동시 생성~~ | ~~실호출 3회 `source=ai`, 10초 이내~~ |
| S1 | ~~`item_key` 규칙 고정(K2)~~ | ~~스키마 값 목록 + 실호출 키 4종 규칙 통과(09-18, 커밋 전)~~ |
| S2 | ~~R2 diff 함수: 이전 루틴 ↔ 새 루틴 `item_key` 비교(added/updated/removed) + 완료 체크 이어받기~~ | ~~`diff.py` + 테스트 6개 통과(전체 69개). DB·API 변경 없음(09-18, 커밋 전)~~ |
| S3 | ~~R1 마이그레이션 + 저장 방식: `daily_routines` 버전별 행(revision·confirmed_at·change_summary), `routine_items`는 현재 상태로 같은 행 갱신(change_kind added/updated/removed), 지난 날짜 중간 버전 정리 함수~~ | ~~SQL Editor 적용·pg_cron 등록, 실DB에서 같은 날 2회 생성 시 `daily_routines` 2행·`routine_items` 중복 없음(09-18, 커밋 전)~~ |
| S4 | R2 응답: `revision`·`is_regeneration`·`change_summary` + `docs/api.md` 갱신 | 재생성 호출 응답에 변경 요약 (선행: S2, S3) |
| S5 | R3 계약 문구: `source != ai` 의미·실패 화면 기준을 `docs/api.md`에 명시 | 문구 반영 |
| S6 | K4 컨디션 저장 API `PUT /api/v1/condition/today` 계약 + 활동 코드표 9종 | 계약 문서화, household `item_key` 값 목록 확정 (선행: 팀 합의) |
| S7 | R4 웰컴 카드 '오늘의 팁' 1개 AI 개인화(FUC-W-HOME-001) — 출력 스키마에 팁 필드 추가 | 실호출 응답에 팁 1개 포함, `docs/api.md` 갱신 (선행: 팁을 AI 출력에 넣을지 결정) |
| S8 | R5 전일 활동·홈캠 요약을 ① 입력에 연결 | `request_payload`에 전일 요약 포함 (선행: 모션 팀과 요약 데이터 계약, K5 UTC/KST 날짜 기준 통일) |

## 4. 가정 (아니면 말해달라)

| # | 가정 | 대안 |
|---|---|---|
| 1 | ~~질의 임베딩 = OpenAI `text-embedding-3-small` (적재와 동일 모델 필수). 생성도 OpenAI → SDK 1개~~ | 생성만 다른 업체 쓰면 SDK 2개 |
| 2 | ~~번역·임베딩은 팀원 스크립트 그대로, 수정 없음~~ | category 룰 보강 시 스크립트 수정 후 재실행 |
| 3 | 산후 자료(`week null` 6건)는 RPC 필터에서 자동 포함됨 → 프롬프트에서 "산후 내용 무시" 지시 | RPC에 `and week_start is not null` 추가 |
| 4 | ~~룰은 yaml~~ | 규칙 20개 초과 시 테이블(현재 16개) |
| 5 | 4개 카테고리 중 하나라도 실패하면 4종 전체 폴백 | 실패 카테고리만 템플릿(부분 폴백). `source` 의미·check 변경 필요해 보류 |
| 6 | ~~(결정1) 루틴 이력 = 버전별 행 누적 + 과거 날짜 중간 버전은 pg_cron으로 정리~~ ✅ 확정 09-18 | 한 행 덮어쓰기 + revision(R1 불충족으로 제외) |
| 7 | ~~(결정2) 재생성 시 내용은 전부 새로 만들고, 완료 기록은 item_key(끼니·부위·가사) 기준으로 유지. 제목 변화는 `change_kind='updated'`로만 표시~~ ✅ 확정 09-18 | 제목이 바뀌면 완료 초기화(실DB에서 공통 5개 중 4개 제목이 바뀌어 거의 매번 초기화되므로 제외) |

## 5. NFR

| NFR | 대응 |
|---|---|
| 001 p50 5초·p95 10초 | ⑥ 타임아웃 9.5초 → 폴백. 임베딩 1회 batch + 생성 4회 동시. **실측 5회 4.99/5.76/6.19/6.22/9.85초(1회 폴백) → p50 미달(K1)** |
| 009 키 | ~~`LLM_API_KEY`(OpenAI) backend `.env`만. 팀원 적재 패키지 `.env`는 저장소 밖~~ |
| 014 최소 전송 | ~~① 선택 항목만 `request_payload` 기록. 이름·이메일 미전송~~ |
| 016 폴백 | ~~전일 → 템플릿 2단~~ |
| 비용(실측) | ~~호출당 약 $0.0067(입력 11,175 / 출력 1,405 토큰 평균, gpt-4.1-mini 입력 $0.40·출력 $1.60 per 1M). 적재 포함 누적 $0.10~~ |

## 6. 진행 기록

| 날짜 | 내용 |
|---|---|
| 2026-09-16 | Supabase 마이그레이션 4건 + `20260917000002_grant_service_role.sql` 적용 확인(5테이블·RPC 접근 OK). 이 프로젝트는 service_role 기본 GRANT가 없어 권한 마이그레이션이 필수 |
| 2026-09-16 | 0-a~0-c, 2~5 코드 작성 완료. 테스트 19개 통과(가짜 Supabase·OpenAI). 적재·실호출은 OpenAI 크레딧 0(`insufficient_quota`)으로 미실행 |
| 2026-09-17 | 적재 완료(88행, 1536차원). 실호출 1회 `source=ai` 8.39초 |
| 2026-09-17 | 버그: 알레르기·입덧 조건에서 식단 0건 → 검증이 설명문의 금지어까지 걸러 전부 삭제. 수정 = `title`·`nutritionTags`만 검사 + `keywords` |
| 2026-09-17 | 성능: 1회 생성 8.4~8.6초로 3회 중 2회 타임아웃 폴백 → 카테고리별 4회 동시 생성. 재실측 3회 모두 `source=ai` 4.99~6.22초 |
| 2026-09-17 | 커밋·push: `66fe1fd` 기능, `d1f268f` 문서(ERD·개발순서 삭제, 이 문서 이름 변경, 적재 jsonl), `3583cc7` migration 주석 |
| 2026-09-18 | 식단 1개만 저장되던 버그 수정: 식단 `item_key`를 `payload.period`로 코드가 만들고, 같은 카테고리에서 키가 겹치면 `:2`·`:3`을 붙여 항목을 버리지 않음(AI·폴백 모두 적용). 테스트 133개 통과 |
| 2026-09-18 | S3 실DB 재확인(third 계정, 원상복구 확인): 같은 컨디션 재생성에서도 공통 5개 중 4개 제목이 바뀜 → 완료 기록을 **키 기준으로 유지**하도록 변경(결정2 확정). 1차 생성에서 식단이 1개만 저장된 현상 발견 — AI가 세 끼에 같은 키를 붙여 중복 처리에서 버려진 것으로 추정, 수정 미결정. 비용 $0.0133. 테스트 132개 통과 |
| 2026-09-18 | S3 실DB 확인: migration 적용·pg_cron 등록(job 1). 같은 날 2회 생성 → `daily_routines` 2행, `routine_items` 8개 중복 0, 기존 7개 같은 행 유지. 단 설명 문장까지 비교해 7개 전부 `updated`로 잡혀 완료 기록이 초기화됨 → **비교 기준을 `title`만으로 변경**(설명은 최신으로 덮어씀). 테스트 132개 통과. 비용 $0.0136 |
| 2026-09-18 | S3 코드·SQL 완료(커밋 전, DB 적용 대기): 항목을 버전별로 새로 넣으면 `routine_items`를 날짜로 읽는 다른 도메인 3곳(guide·care·family)에 중복이 생겨, 항목은 현재 상태로 같은 행을 갱신하고 이력은 `daily_routines.response`에만 쌓는 방식으로 변경. 참조 중이라 삭제가 막힌 항목은 `change_kind='removed'`. 테스트 131개 통과 |
| 2026-09-18 | 협업 규칙 개정(팀 합의): 보호 테이블은 `posture_*` 2개와 `auth.users`만. Routine AI 테이블은 Routine AI 담당 단독 변경 가능(`docs/development/BACKEND_COLLABORATION.md` §2.4) |
| 2026-09-18 | S2 완료(커밋 전): `diff.py` — `item_key` 기준 added/updated/removed/unchanged + 내용 동일 항목만 완료 기록 이어받기(`change_kind` 부여). 비교는 `title`·`description`·`payload`만, `source_ids`·`sort_order`는 제외. 테스트 69개 통과 |
| 2026-09-18 | S1 완료(커밋 전): `item_key` 스키마 값 목록 고정 + household 접두사 보정. 테스트 63개 통과. 실호출 2회(9.85초 폴백 1회, `source=ai` 6.19초 1회에 키 규칙 통과) |

남은 실행 확인:
1. ~~마이그레이션 실행~~ 완료(2026-09-16)
2. ~~`tools/rag_ingest`에서 `--step all` → `select count(*) from pregnancy_knowledge` ≥ 75~~ 완료(2026-09-17, 88행)
3. ~~실호출 → `source=ai`, `source_ids` 채워짐 확인~~ 완료(2026-09-17, 3회)
4. ~~S3 migration을 SQL Editor에서 적용 → **코드 배포(push)보다 먼저**. 적용 전에 이 코드가 돌면 `revision` 컬럼이 없어 저장이 실패한다~~ 완료(2026-09-18)
5. ~~pg_cron 켜고 정리 스케줄 등록(migration 파일 하단 주석의 SQL)~~ 완료(2026-09-18, job 1)
6. ~~적용 후 실DB 확인: 같은 날 2회 생성 → `daily_routines` 2행, `routine_items` 중복 없음~~ 완료(2026-09-18, 2회)
7. S1~S3 수정분 커밋·push + 팀원에게 `routine_items.change_kind` 추가 공지
8. S4 이후는 §3 표 기준으로 진행. 결정1 확정(09-18), 결정2는 추천안(전부 재생성)으로 S2·S3에 반영

## 7. 남은 것 (요구사항 변경·알려진 문제)

### 7.1 요구사항 변경 (2026-09-17 흐름도 `02_AI하루루틴생성.mmd`, 04_1 개정)

| # | 요구 | 현재 | 단계 |
|---|---|---|---|
| R1 | 확정 후 컨디션 재입력 = 덮어쓰지 않고 새 루틴(FUC-W-COND-004), Daily 리포트는 날짜당 1개(NFR-028) | `daily_routines` 사용자·날짜당 1행 덮어쓰기, 확정 상태 없음 | S3 |
| R2 | 확정 전 수정 = 루틴 재생성 + 남편 알림(FUC-W-COND-003, FUC-H-NOTI-002) | 재생성 신호 없음, 완료 체크 유실 | S2, S4 |
| R3 | AI 실패 → 실패 화면(W-CALLBACK-001) + 다시 시도 → 연속 실패 시 폴백 | 실패 즉시 폴백 저장 후 201 | S5 |
| R4 | 웰컴 카드 '오늘의 팁' 1개 AI 개인화(FUC-W-HOME-001) | 출력 4종뿐 | S7 |
| R5 | 입력에 전일 활동·홈캠 데이터 | 미포함 | S8 |

### 7.2 알려진 문제

| # | 문제 |
|---|---|
| K1 | NFR-001 p50 5초 미달(실측 중간값 6.19초, 1회는 9.85초 타임아웃 폴백). 출력 분량 제한 또는 모델 검토 |
| ~~K2~~ | ~~AI가 만든 `item_key`가 `breakfast_1` 형식(설계 `meal:lunch`)~~ → S1에서 고정 완료(09-18) |
| K3 | `daily_conditions.sleep_quality`·`LLM_FACT_KEYS`에 수면 값 잔존. 04_1 컨디션 입력 4종에 수면 없음 |
| K4 | 컨디션 저장 API 없음 → 실제 앱에선 항상 409. 활동 코드표 9종(프론트 한글 라벨 vs 백엔드 코드) 확정 필요 → S6 |
| K5 | 날짜 기준 모션=UTC, 웬즈데이=KST |
| K6 | 옛 요구사항 ID `W-ROUTINE-001/003`이 코드 주석·`backend/README.md`·`docs/api.md`·`fallback.yaml`·migration 주석에 남음 → `W-HOME-001`/`W-CALLBACK-001` |
| K7 | MediaPipe 추론이 이벤트 루프 동기 점유 → 웬즈데이 응답 지연 위험. 마이그레이션 접두사 `20260916000000` 중복 |
