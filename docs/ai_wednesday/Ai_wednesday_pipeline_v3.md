# AI 하루 루틴 생성 파이프라인 v3 (웬즈데이 AI)

- 최초 작성: 2026-09-16 / v3 갱신: 2026-09-18 (컨디션 수정 영향 누적·부분 재생성 추가)
- 표기: ~~취소선~~ = 완료된 부분. 작업이 끝나 커밋할 때 취소선을 지운다.
- 실호출 규칙(2026-09-18 확정): 계정 `testwife@gmail.com` + 테스트 전용 날짜 `2026-12-31`만 사용(오늘 날짜·팀원 데이터 건드리지 않음, 프로필은 읽기만). `POST /api/v1/routine/today`를 실제 API 경로로 호출해 남편 알림(testhusband `notifications` 행 생성)까지 확인. 정리는 testwife·testhusband의 2026-12-31 행만 삭제하고 실행 전후 행 수로 원상복구 확인
- 작업 디렉토리: `/Users/ella/PLM`
- 관련 기능: W-HOME-001(구 W-ROUTINE-001), W-CALLBACK-001(구 W-ROUTINE-003), W-MEAL-002, W-HEALTH-001, W-SLEEP-001, W-HOUSE-001
- 관련 문서: `docs/api.md`, `docs/backend/TARGET_DB_SCHEMA.md`, `docs/서비스흐름도/02_AI하루루틴생성.mmd`, `docs/requirements/04_1`, `04_2`
- 이번 수정(2026-09-18): 컨디션 재입력 시 복수 항목의 영향을 카테고리별로 누적하고, 필요한 가이드만 부분 조정하는 요구(R6·R7)를 S9·S10으로 추가. 아래 취소선은 당시 완료 이력이므로 유지하며, 새 수정 정책의 구현 완료를 뜻하지 않는다.

```text
Flutter ─▶ FastAPI ─┬─ Supabase (pregnancy_profiles · daily_conditions · pregnancy_knowledge[pgvector])
                    ├─ Rule Engine (rules.yaml)
                    └─ OpenAI API (질의 임베딩 text-embedding-3-small 1536 + 루틴 생성 json_schema ×4 카테고리)
                              ▼
                  {meal, household, health, sleep}
```

## v2 → v3 변경

| 항목 | v2 | v3 |
|---|---|---|
| 컨디션 수정 판단 | 항목 변화량·가이드별 누적 영향 판단 없음 | S9 `Impact Resolver`: 변경 항목별 변화·경계·관계를 해석하고 카테고리별 악화·호전 압력을 별도 누적 |
| 여러 컨디션 동시 변경 | 전체 변화 조합을 가이드별로 반영하는 기준 없음 | 같은 가이드의 변화를 합치고, 악화·호전을 상쇄하지 않음. `mode`·`strength`·`direction` 결정 |
| 변경 범위 | 재생성 시 4종 루틴을 모두 새로 생성 | S10: 관련 가이드만 TUNE/REPLAN, 무관한 가이드는 KEEP하여 이전 revision과 병합 |
| 연관 가이드 | 항목과 다른 가이드의 영향 관계·예정 활동 조건 없음 | primary/secondary 매핑. secondary는 실제 예정 활동이나 제공 가능한 보조 대책이 있을 때만 반영 |
| 프롬프트 | 현재 상태·룰·RAG로 카테고리별 신규 생성 | 이전 카테고리 루틴과 영향 분석을 추가 전달하여 필요한 내용만 수정 |
| 수정 실패 | 한 카테고리 실패 시 4종 전체 폴백 가정 | 수정 대상 카테고리만 안전 검증·유지 또는 부분 폴백; 무관한 가이드 유지 |
| 이력·응답 | 기존 `item_key`·diff·revision 기반 | 기존 체계 유지 + 변경 항목·가이드별 결정·실제 재생성 카테고리를 기록 |

### 기존 파이프라인 선택 이력 (완료 표시 보존)

| 항목 | 대체 전 선택지 | 적용 완료 이력 |
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

위 ①~⑦ 표의 완료 표시는 **최초 루틴 생성 경로**의 이력이다. 컨디션 수정 요청의 추가 경로는 §2.5~2.8과 S9·S10에 정의한다. 최초 생성은 기존 4종 병렬 생성, 수정은 카테고리별 영향 판단 후 부분 생성으로 구분한다.

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

S9·S10에서 `backend/app/services/routine/impact_map.yaml`(항목→카테고리 영향·척도 방향)과 `impact.py`(변화량·누적 영향 판단)를 추가하고, `prompt.py`·`generator.py`·`service.py`를 수정한다. 위 기존 파일 목록은 완료 이력 기준이며 이 추가 파일은 아직 미구현이다.

### 2.5 컨디션 수정 경로: S9 / R6 (복수 항목 영향 누적)

```text
이전 컨디션 + 현재 컨디션 + 예정 활동
  → 항목별 diff(방향·변화량·4/5 경계)
  → impact_map의 primary/secondary 관계 적용
  → 카테고리별 악화 압력·호전 압력 별도 누적
  → 복수 컨디션 조합과 실제 수행할 일 확인
  → {mode, strength, direction, contributors} 결정
  → 현재 절대값으로 Rule Engine 안전 규칙 재평가
```

- 1~5 척도에서 값이 커질수록 악화되는 항목은 `delta = current - previous`가 양수면 악화, 음수면 호전이다. 항목별 척도 방향을 `impact_map.yaml`에 명시하고, 반대 의미의 항목에는 이 부호를 그대로 적용하지 않는다. 값이 같으면 변화 기여도 0이다.
- `impact_map.yaml`은 항목별 **primary** 가이드, 명시적으로 관련된 **secondary** 가이드, secondary가 실제 조정 대상이 되는 조건을 기록한다. 예시 매핑: 허리·손목 통증 → `health` primary / 가사 예정 시 `household` secondary, 입덧 → `meal` primary / 생활 자세 등 대응이 필요할 때 `health` secondary. 실제 키는 `daily_conditions` 계약에 맞춘다. 관련성 없는 `sleep`·`meal`에 통증 변화 점수를 전파하지 않는다.
- 항목 한 개의 작은 변화만 보고 결론을 내리거나, 카테고리에서 가장 큰 변화 하나만 고르지 않는다. 같은 가이드에 연결된 여러 변화는 모두 합친다. 악화와 호전은 서로 상쇄하지 않고 별도 압력으로 보관한다. 현재 전체 컨디션은 안전 규칙과 맥락에 사용하되, **바뀌지 않은 항목을 변경 원인으로 기록하지 않는다.**

| 항목별 기여도 계산의 초기 제안값 | 점수 |
|---|---:|
| 변화 없음 | 0 |
| 1칸 변화 | 1 |
| 2칸 이상 변화 | 2 |
| 4단계 경계 진입/이탈 | +1 |
| 5단계 진입/이탈 | +1 |
| primary / secondary 가중치 | ×1.0 / ×0.5 |

이 점수와 아래 `strength` 경계는 **S9에서 테스트로 고정할 초기 제안값**이다. 4단계는 현행 `rules.yaml`의 주요 임계값이므로, 안전 규칙은 점수보다 항상 우선한다. `abs(delta) >= 2`, 4단계 경계 또는 5단계 진입/이탈은 항목 단위 `REPLAN` 신호다. 점수는 악화·호전 각각의 압력에 더하고 서로 빼지 않는다.

| 카테고리 결정 | 초기 제안 기준 |
|---|---|
| `mode=KEEP` | 관련 변화가 없거나, secondary의 약한 기여만 있고 그 가이드에서 실행 가능한 대응이 없는 경우 |
| `mode=TUNE` | 관련 변화가 있으나 아래 `REPLAN` 조건에는 못 미치는 경우. 이전 `item_key`와 항목 수를 유지하고 필요한 세부 값만 수정 |
| `mode=REPLAN` | 관련 primary에 항목 단위 `REPLAN` 신호가 있거나, 카테고리의 악화·호전 압력 중 큰 값이 2 이상. 해당 가이드 내부만 재평가 |
| `strength=none/low/medium/high` | 압력의 큰 값이 0 / 0 초과~1.5 미만 / 1.5 이상~3 미만 / 3 이상 |
| `direction=worsened/improved/mixed/unchanged` | 한쪽 압력만 있으면 그 방향, 양쪽이 있고 작은 압력이 큰 압력의 절반 이상이면 `mixed`, 그보다 작으면 우세한 방향, 둘 다 0이면 `unchanged` |

`strength`는 **루틴을 얼마나 수정할지**의 범위다. `high`가 더 강한 운동이나 의학적 처치를 뜻하지 않는다. secondary만으로 변경할 때는 해당 가이드에 실제로 수행할 일 또는 제공할 수 있는 보조 대책이 있는지 확인한다. 예컨대 가사 예정이 없으면 허리·손목 악화만으로 `household`를 변경하지 않는다. 반면 빨래·청소가 예정돼 있으면 누적된 가사 부담을 반영한다.

```json
{
  "changed_conditions": [
    {"key":"waist_pain","from":2,"to":3,"direction":"worsened","impact":1},
    {"key":"wrist_pain","from":3,"to":4,"direction":"worsened","impact":2,"threshold_crossed":true},
    {"key":"nausea","from":3,"to":2,"direction":"improved","impact":1}
  ],
  "category_impacts": {
    "health":{"mode":"REPLAN","strength":"high","direction":"worsened","worsening_pressure":3.0,"improvement_pressure":0.5,"contributors":["waist_pain","wrist_pain","nausea"]},
    "meal":{"mode":"TUNE","strength":"low","direction":"improved","worsening_pressure":0,"improvement_pressure":1.0,"contributors":["nausea"]},
    "household":{"mode":"TUNE","strength":"medium","direction":"worsened","worsening_pressure":1.5,"improvement_pressure":0,"contributors":["waist_pain","wrist_pain"]},
    "sleep":{"mode":"KEEP","strength":"none","direction":"unchanged","worsening_pressure":0,"improvement_pressure":0,"contributors":[]}
  }
}
```

위 `household=TUNE`은 **관련 가사가 예정된 경우**다. 예정 가사가 없으면 `household=KEEP`으로 확정한다. `health`에서는 허리·손목 악화 압력 3.0과 입덧 완화 압력 0.5를 함께 전달하되 상쇄하지 않는다. `meal`은 입덧 완화에 맞춰 소폭 완화한다. 허리 통증만 `2→3`이면 기본적으로 `health=TUNE`, 다른 카테고리는 `KEEP`이다. 입덧 `3→5`는 `meal=REPLAN`, 연결된 생활 건강 대응이 있으면 `health=REPLAN`이며 나머지는 `KEEP`이다. 허리 호전과 손목 악화가 동시에 큰 경우 `health.direction=mixed`로 각각 다르게 조정한다.

### 2.6 부분 재생성·저장: S10 / R7

| 경로 | 동작 |
|---|---|
| 최초 생성 | 기존 4개 카테고리 Rule·RAG·LLM 병렬 호출 유지 |
| 컨디션 수정 `KEEP` | 해당 카테고리 호출 없이 직전 revision의 루틴 유지 |
| 컨디션 수정 `TUNE` | 기존 카테고리 루틴을 전달. `item_key`·항목 수 유지, 가능하면 제목 유지. 필요한 `durationMin`·`loads`·`guide`·`reason`·`cautions`·수행 방식만 조정 |
| 컨디션 수정 `REPLAN` | 대상 카테고리 내부에서 부적절한 항목을 교체하거나 여러 세부 사항을 재평가. 가능하면 기존 `item_key` 의미를 유지 |
| 수정 결과 | 변경된 카테고리만 새 결과로 대체 → 나머지 카테고리와 병합 → 기존 `diff.py`로 차이·완료 기록 처리 → `revision` 및 `change_summary` 저장 |

`Rule Engine`은 **현재 절대값에서 허용·제한·필수인 것**을 판단하고, `Impact Resolver`는 **무엇을 어느 정도 다시 계산할지**를 판단한다. 대상 카테고리에만 Rule·RAG·LLM을 실행한다. `request_payload`에 변경 항목, 카테고리별 결정과 압력, 실제 생성 카테고리를 남기고 `change_summary`에는 변경 사유와 변경 카테고리를 기록한다. `source`가 AI 생성·직전 버전 유지·부분 폴백이 섞일 때의 응답 의미는 S5와 함께 `docs/api.md`에 명시한다.

수정 중 한 카테고리의 생성이 실패해도 **다른 카테고리를 4종 전체 폴백으로 바꾸지 않는다.** 실패 카테고리의 이전 루틴을 현재 Rule로 검증해 안전하면 유지하고, 부적절하면 그 카테고리 전용 폴백을 검토한다. 둘 다 불가능하면 R3 실패 흐름을 사용한다. 저장 시 한 revision 안에서 루틴 4종·`routine_items`·변경 요약이 서로 일치해야 한다.

### 2.7 S10 프롬프트 (`prompt.py`의 수정 호출용)

공통 System Prompt의 수정 호출 분기. 생성 범위는 백엔드의 `category_decision`이 결정하며, LLM이 다른 카테고리의 수정 필요 여부를 다시 결정하지 않는다.

```text
당신은 PLM 임산부 생활관리 AI '웬즈데이'의 지정 카테고리 루틴 조정 엔진이다.
임신 주차, 현재 전체 컨디션, 이번에 변경된 컨디션, 예정 활동,
이전 target_category 루틴, Rule Engine 결과와 제공된 pregnancy knowledge를 사용한다.

[범위와 안전]
1. target_category 외의 meal/household/health/sleep 루틴을 생성하거나 변경하지 않는다.
2. 백엔드가 정한 category_decision.mode(KEEP/TUNE/REPLAN), strength, direction을 따른다.
   KEEP 카테고리는 호출 대상이 아니다. high는 수정 범위이지 의학적 처치 강도가 아니다.
3. 여러 변경을 함께 고려한다. 같은 카테고리의 악화 신호는 누적하고,
   악화와 호전은 서로 상쇄하지 않는다. mixed이면 항목별로 다른 조정을 한다.
4. condition_changes 중 target_category의 primary 또는 명시된 secondary 관계만
   수정의 근거로 사용한다. 다른 항목은 현재 상태의 안전 맥락으로만 본다.
5. Rule Engine의 exclude/limit/require가 항상 우선한다.
   RAG에 없는 의학적 사실, 진단, 치료 효과를 만들어내지 않는다.
6. 이전 루틴을 기준으로 판단하고, 불필요한 교체를 피한다.
   악화 시 부담을 키우지 않으며, 호전 시 제한을 점진적으로 완화한다.
7. 출력은 지정된 category JSON schema만 따른다. schema 밖 필드는 넣지 않는다.

[TUNE]
기존 item_key와 항목 수를 유지한다. 가능하면 title도 유지한다.
현재 상태에 필요한 일부 세부 값만 바꾼다. 관련 없는 항목은 그대로 둔다.
사용자가 변경을 인지할 최소한의 조정은 하되 루틴 전체를 새로 쓰지 않는다.

[REPLAN]
target_category 안에서만 여러 항목을 재평가할 수 있다.
부적절한 추천은 바꾸되 기존 item_key의 의미적 슬롯은 가능한 한 유지한다.
secondary 영향이라면 그 카테고리가 담당할 수 있는 보조 대책만 제공한다.

[카테고리 책임]
meal=식사 구성·시점·음식 선택, household=가사 수행·분담·부담,
health=움직임·자세·활동 강도·생활 건강, sleep=취침·수면 환경·준비.
```

호출별 User Prompt. `condition_changes_json`에는 모든 변경 사실을 제공하되, `category_contributors_json`으로 이 카테고리의 직접 근거를 분리한다.

```text
다음 정보를 기준으로 {target_category} 루틴만 조정하세요.

[카테고리 결정] {category_decision_json}
[이번에 변경된 전체 컨디션] {condition_changes_json}
[이 가이드에 기여한 변경과 primary/secondary 관계] {category_contributors_json}
[현재 전체 컨디션] {current_conditions_json}
[예정 활동] {scheduled_activities_json}
[기존 {target_category} 루틴] {previous_category_routine_json}
[현재 Rule Engine 결과] {category_rules_json}
[검색된 임신 생활 가이드 근거] {rag_context_json}

악화와 호전을 하나의 점수로 상쇄하지 마세요.
category_decision의 mode·strength 범위에서 기존 루틴을 필요한 만큼만 조정하세요.
다른 카테고리의 루틴을 출력하거나 관련 없는 변화를 수정 이유로 삼지 마세요.
Rule Engine을 준수하고, 근거 밖 의학적 내용을 추가하지 마세요.
반드시 지정된 category JSON schema만 출력하세요.
```

### 2.8 S9·S10 완료 확인 사례

| 입력 | 기대 결과 |
|---|---|
| 허리 `3→3` | 네 카테고리 `KEEP`, 수정 호출 0회 |
| 허리 `2→3` | `health=TUNE`; 식사·수면의 기존 항목은 그대로 새 revision에 병합 |
| 허리 `3→4` | Rule 재평가, `health=REPLAN`; 가사 예정 여부에 따라 `household` 결정 |
| 입덧 `3→5` | `meal=REPLAN`; 건강 보조 대책이 관련되면 `health=REPLAN`; 무관한 가이드는 유지 |
| 허리 `2→3` + 손목 `3→4` + 입덧 `3→2` | 건강 악화 3.0·호전 0.5로 `REPLAN/high/worsened`, 식사 `TUNE/low/improved`; 가사 일정이 있으면 가사 영향 누적, 없으면 `KEEP`; 수면 `KEEP` |
| 허리 크게 호전 + 손목 크게 악화 | 건강 `mixed`; 호전·악화를 0으로 상쇄하지 않고 각각 반영 |
| 수정 대상 한 카테고리 생성 실패 | 무관한 가이드는 그대로, 실패 카테고리만 안전 검증·폴백 또는 R3 실패 흐름 |

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
| S4 | ~~R2 응답: `revision`·`is_regeneration`·`change_summary` + `docs/api.md` 갱신~~ | ~~재생성 호출 응답에 변경 요약 (선행: S2, S3) — GET·POST 응답 필드 추가, 남편 알림 분기를 `is_regeneration`으로 통일, 테스트 165개 통과(09-18, 커밋 전)~~ |
| S5 | ~~R3 계약 문구: `source != ai` 의미·실패 화면 기준을 `docs/api.md`에 명시~~ | ~~문구 반영 — `docs/api.md` "AI 실패 처리" 절 추가. 폴백이면 남편 알림 없음, 첫 알림은 오늘 첫 AI 루틴 기준(폴백 뒤 재시도 성공 = 오전 리포트). 테스트 167개 통과(09-18, 커밋 전)~~ |
| S6 | ~~K4 컨디션 저장 API `PUT /api/v1/condition/today` 계약 + 활동 코드표 9종~~ | ~~계약 문서화, household `item_key` 값 목록 확정 (선행: 팀 합의) — 저장 API는 팀원의 기존 `PUT /care/conditions/{date}`·`/activities`를 사용(신규 없음). 코드표는 `inputs.py` `ACTIVITY_CODES`(DB는 한글 라벨 유지, 입력 단계에서만 변환), household 키 10종 enum, `docs/api.md` 호출 순서·코드표. 테스트 168개 통과(09-18, 커밋 전)~~ |
| S7 | ~~R4 웰컴 카드 '오늘의 팁' 1개 AI 개인화(FUC-W-HOME-001) — 출력 스키마에 팁 필드 추가~~ | ~~실호출 응답에 팁 1개 포함, `docs/api.md` 갱신 (선행: 팁을 AI 출력에 넣을지 결정) — 5번째 동시 호출(`TIP_SCHEMA`), `response.tip={text, source_ids}` 또는 null, 팁 실패·지연·금지어는 tip=null로 루틴과 분리. 테스트 173개, 실호출 팁 포함 확인(09-18, 커밋 전)~~ |
| S8 | ~~R5 전일 활동·홈캠 요약을 ① 입력에 연결~~ | ~~`request_payload`에 전일 요약 포함 (선행: 모션 팀과 요약 데이터 계약, K5 UTC/KST 날짜 기준 통일) — 모션 팀 요약 함수 읽기만(계약 신규 없음), K5 1안, `facts.yesterday={routine, motion}`. 테스트 4개 추가, 실호출 `source=ai` 확인(09-19, 커밋 전)~~ |
| S9 | ~~R6 컨디션 diff + `impact_map.yaml`·`impact.py`: 항목별 변화와 경계값 판단, primary/secondary 매핑, 카테고리별 악화·호전 압력 누적, `mode`·`strength`·`direction` 결정~~ | ~~§2.5·§2.8 사례 고정 테스트. 복수 악화 누적·상반 변화 비상쇄·예정 가사 조건·척도 방향 확인 (선행: S6 컨디션 필드·활동 코드 계약) — `impact_map.yaml`·`impact.py`(`resolve_impact`), 이전 컨디션은 그날 최신 revision의 `request_payload`에서 읽음(09-19 결정, 연결은 S10). §2.8 사례 6개 + 기분 척도 반전·예정 활동 변경·미변경 항목 제외 테스트 9개, 전체 190개 통과(09-19, 커밋 전)~~ |
| S10 | ~~R7 컨디션 수정 시 대상 가이드만 Rule·RAG·LLM 호출, 이전 루틴 기반 TUNE/REPLAN 프롬프트, KEEP 병합, 부분 실패 처리, diff/revision·API 문서 연결~~ | ~~수정된 카테고리만 호출·저장, 미대상 항목과 완료 기록 보존, 실패 시 무관한 가이드 불변. `docs/api.md`의 `source`·`change_summary` 계약 갱신 (선행: S4, S5, S9) — 수정 경로 실호출 확인: 대상 가이드만 호출, 미대상 항목 id·완료 기록 유지, 변화 없으면 호출·새 버전 없음(09-20, push 전)~~ |
| S_stretching_video | ~~건강 가이드 대표 활동 스트레칭 영상(FUC-W-HEALTH-001 "대표 활동(영상·소요 시간)"): 부위별 영상 목록 파일(`health:<부위>` → 제목·URL·길이)을 두고 백엔드가 health 항목에 `video` 필드를 붙인다. AI는 영상 URL을 만들지 않는다~~ | ~~건강 항목 응답에 `video` 포함, `docs/api.md` payload 표 갱신 (선행: 팀이 부위별 영상 6종 URL 선정 — 허리·골반·다리·손목·전신·휴식) — 목록 파일 `stretching_videos.yaml`(6부위) + `service.attach_videos()`가 `payload.video`에 붙임. **URL은 팀 선정 대기라 전부 빈 값**이고, 빈 부위는 `video` 키를 붙이지 않는다. `docs/api.md` payload 표 갱신. 테스트 3개. 팀이 URL만 채우면 코드 수정 없이 적용(09-20, 커밋 전)~~ |
| S_createroutine_loading | ~~루틴 생성·수정 대기 시간을 로딩 화면으로 가리기(09-18 회의 의견). 백엔드는 `docs/api.md`에 대기 계약만 명시: 예상 시간(p50·p95 실측), 서버 상한 9.5초 뒤 폴백 응답, 앱 요청 타임아웃은 12초 이상, 로딩 중 버튼 비활성으로 중복 호출 금지. 화면 구현은 프론트 팀~~ | ~~`docs/api.md` 대기 계약 반영, 프론트 팀 확인 (선행: K1 실측값 갱신. 로딩 화면은 체감 대기만 줄이고 9.5초 초과 폴백은 줄이지 못함) — 백엔드 몫인 대기 계약을 `docs/api.md` '생성 대기 화면' 절에 명시: 로딩 중 버튼 비활성(중복 호출 금지), 앱 타임아웃 12초 이상, 실측 중앙값 7.7초·최대 10.2초·폴백 9회 중 4회, 수정 경로 4.9초. 화면 구현은 프론트 팀 몫(09-20, 커밋 전)~~ |
| S_date_modification | 팀원 테스트 `backend/tests/test_guide_query.py`의 `TARGET_DATE`를 고정값 `date(2026, 9, 18)`에서 실행일 `dates.today_kst()`로 바꿈(09-19, 커밋 전. 고정값이면 다음 날부터 `/today` 조회가 404). 팀원이 고정 날짜를 원하면 `TARGET_DATE`를 다시 고정하고 테스트에서 `app.utils.dates.today_kst`를 같은 날짜로 `patch`해 API 오늘 날짜도 고정한다 | 팀원 결정 후 `test_guide_query` 10개 통과, 날짜를 바꿔 실행해도 통과 (선행: 팀원 회신) |

## 4. 가정 (아니면 말해달라)

| # | 가정 | 대안 |
|---|---|---|
| 1 | ~~질의 임베딩 = OpenAI `text-embedding-3-small` (적재와 동일 모델 필수). 생성도 OpenAI → SDK 1개~~ | 생성만 다른 업체 쓰면 SDK 2개 |
| 2 | ~~번역·임베딩은 팀원 스크립트 그대로, 수정 없음~~ | category 룰 보강 시 스크립트 수정 후 재실행 |
| 3 | ~~산후 자료(`week null` 6건)는 RPC 필터에서 자동 포함됨 → 프롬프트에서 "산후 내용 무시" 지시 → `SYSTEM_PROMPT`에 반영 완료~~ | RPC에 `and week_start is not null` 추가 |
| 4 | ~~룰은 yaml~~ | 규칙 20개 초과 시 테이블(현재 16개) |
| 5 | ~~최초 생성의 현행 동작: 4개 카테고리 중 하나라도 실패하면 4종 전체 폴백. **컨디션 수정은 R7/S10에서 실패 카테고리만 안전 검증·유지 또는 부분 폴백** → S10 완료(09-20): 실패 가이드는 직전 내용 유지, 전부 실패면 `fallback_prev`~~ | 수정 요청까지 4종 전체 폴백을 적용하는 기존 가정은 R7과 충돌. `source` 의미·check는 S5/S10에서 정의 |
| 6 | ~~(결정1) 루틴 이력 = 버전별 행 누적 + 과거 날짜 중간 버전은 pg_cron으로 정리~~ ✅ 확정 09-18 | 한 행 덮어쓰기 + revision(R1 불충족으로 제외) |
| 7 | ~~(결정2) 재생성 시 내용은 전부 새로 만들고, 완료 기록은 item_key(끼니·부위·가사) 기준으로 유지. 제목 변화는 `change_kind='updated'`로만 표시~~ ✅ 확정 09-18 | 제목이 바뀌면 완료 초기화(실DB에서 공통 5개 중 4개 제목이 바뀌어 거의 매번 초기화되므로 제외) |
| 8 | ~~결정2의 취소선은 당시 완료 이력으로 보존. **S9·S10 적용 이후 컨디션 수정 요청에는 '전부 새로 만들기'를 적용하지 않고** 관련 가이드만 TUNE/REPLAN한다. `item_key` 기준 완료 기록 처리와 revision 이력은 유지 → S9·S10 적용 완료(09-20)~~ | 전체 재생성은 최초 생성 또는 별도 명시된 전체 재계획 요청에 한정 |

## 5. NFR

| NFR | 대응 |
|---|---|
| 001 p50 5초·p95 10초 | ⑥ 타임아웃 9.5초 → 폴백. 임베딩 1회 batch + 생성 4회 동시 + 식단 출력 제한(K1, 09-20). **실측 09-20 3회 4.99/5.39/8.26초(폴백 0) → p50 5.4초로 목표에 근접하나 미달**. 제한 전 9회는 중앙값 7.7초·폴백 4회. 컨디션 수정 경로는 대상 가이드만 호출해 4.9초(1회) |
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
| 2026-09-20 | K9 해소(커밋 전): 피드백이 달린 항목은 삭제하지 않고 `removed` 표시(테스트 2개 추가, 전체 206개 통과). `recommendation_feedback`의 cascade는 Care 담당이 09-17 `f88a8dc`에 만든 것으로 확인 |
| 2026-09-20 | K9를 §7.2에 기록(재생성 시 메뉴 피드백 cascade 삭제). K7·K9·영상 URL은 팀 공유 항목으로 정리 |
| 2026-09-20 | K1 개선(커밋 전): 가장 느린 식단 호출의 출력 분량을 지시문으로 제한(`PROMPT_VERSION=2026-09-20.1`). 실호출 3회(testwife 2026-12-31, 원상복구 확인) 4.99/5.39/8.26초 모두 `source=ai`, 카테고리별 식단 3.92~5.21 / 건강 3.38~3.87 / 수면 2.50~3.19 / 가사 1.19~2.36초, 식단 출력 444~488토큰(이전 807). 비용 $0.0204(3회 합계). `docs/api.md` 대기 계약 수치도 갱신 |
| 2026-09-20 | K3·K6·K8 해소(커밋 전): K3 = 루틴 입력에서 `sleep_quality` 제외(Care 계약 테스트 1줄 수정), K8 = 폴백 가사 항목을 예정 활동 코드로 생성해 폴백→AI 성공 때 같은 행 유지(실패 시 항목 7→6개), K6 = 옛 화면 ID를 웬즈데이 소유 파일 7곳에서 정리. 테스트 3개 추가, 전체 203개 통과. K7은 모션 담당 영역이라 팀 공유로 남김 |
| 2026-09-20 | S_stretching_video·S_createroutine_loading 진행(커밋 전): 영상은 목록 파일 + `attach_videos()`까지 만들고 URL은 팀 선정 대기(빈 값이면 `video` 키 없음). 로딩은 `docs/api.md`에 대기 계약 명시(버튼 비활성·앱 타임아웃 12초 이상·실측 중앙값 7.7초·9회 중 4회 폴백). 테스트 3개 추가, 전체 200개 통과 |
| 2026-09-20 | S10 완료: 실호출(testwife 2026-12-31, API 경로, 원상복구 확인) — 1차 전체 생성 `source=ai` 6.52초(5호출), 허리 2→4 수정 4.90초에 `routine_edit_health`·`routine_edit_household`·팁만 호출(`generated=['household','health']`, 실패 0). 판단 = health REPLAN/high/worsened, household TUNE/medium/worsened, meal·sleep KEEP. 식사·수면 항목 4개 id 그대로, `change_summary.categories/conditions` 저장 확인. 같은 컨디션 재호출은 0.15초·호출 0회·새 버전 없음(결정1). 남편 알림 `morning_report` + `condition_changed`. 비용 합계 $0.0114(수정 호출분 $0.0045) |
| 2026-09-19 | S10 코드 작성(커밋 전, 실호출 확인 전): 확정 전 루틴이 있고 직전이 `source=ai`면 수정 경로 — 직전 revision `request_payload`와 비교(S9) → TUNE·REPLAN 가이드만 검색·수정 호출(`generate_edit`, `EDIT_SYSTEM_PROMPT`=§2.7) 동시 실행, 팁도 재생성 → 직전 루틴에 병합 후 현재 규칙으로 4종 재검사 → 기존 저장(`change_summary`에 `categories`·`conditions` 추가). 결정1: 전부 KEEP이면 새 버전·호출·알림 없음. 결정2: 실패 가이드는 직전 내용 유지(규칙에 다 걸리면 템플릿), 하나라도 성공 `ai`·전부 실패 `fallback_prev`(의미를 '직전 버전 유지'까지 확장), 실패 가이드는 다음 호출에서 재시도. 직전이 폴백이거나 확정됐으면 4종 전체 생성. `PROMPT_VERSION=2026-09-19.2`, `docs/api.md` '컨디션 수정 경로' 절. 테스트 7개 추가·1개 수정, 전체 197개 통과. 실호출 1회차: 첫 생성 9.88초 타임아웃 → `fallback_prev`(수정 경로 미도달), 원상복구 확인, 약 $0.0038 |
| 2026-09-19 | S9 완료(커밋 전): `impact_map.yaml`(항목별 척도 방향·primary/secondary·점수) + `impact.py` `resolve_impact(previous, current)` → `changed_conditions`·`category_impacts`(mode·strength·direction·압력·contributors). 이전 컨디션은 `daily_conditions`가 덮어쓰기라 그날 최신 revision의 `request_payload`에서 읽기로 결정(DB 변경 없음). 매핑 가정: 입덧→식사(건강 secondary), 통증 4부위→건강(가사 secondary, 예정 가사 있을 때만), 피로→건강·수면(가사 secondary), 기분→수면(건강 secondary, 척도 반전), 예정 활동 변경→가사 REPLAN, `sleep_quality` 제외(K3). AI·DB 호출 없음, 비용 0. 테스트 9개 추가, 전체 190개 통과 |
| 2026-09-19 | S8 완료(커밋 전): 실호출 2회차(testwife 2026-12-31, API 경로, 원상복구 확인) `source=ai` 7.69초, `prompt_version=2026-09-19.1`, `request_payload.yesterday={routine: null, motion: null}`(12-30 데이터 없음), 건강 5개·팁 포함, 남편 알림 `morning_report` 1건. 비용 약 $0.0069(임베딩 제외). 부위 매핑은 `backend/README.md`에 명시. 로딩 화면 과제 `S_createroutine_loading` 추가 |
| 2026-09-19 | S8 코드 작성(커밋 전): 전일 요약 `facts.yesterday = {routine, motion}`를 ① 입력·`request_payload`에 추가. routine = 어제 `routine_items` 완료 수·전체 수·미완료 키(`removed` 제외), motion = 모션 팀 `generate_daily_report()`를 읽기만 해 부위·허리 숙임 부담 횟수·전방굴곡 분만 전달(설명 문장 제외, NFR-014). 부위는 `trunk→waist`, `knee→leg`, `whole_body→whole`. 데이터 없음·조회 실패는 `null`이고 루틴은 막지 않음. 지시문 3줄 추가, `PROMPT_VERSION=2026-09-19.1`. 전일 조회 0.05~0.11초(실측, 타임아웃 예산 밖에서 실행). 테스트 181개 중 179개 통과(실패 2개는 팀원 `test_guide_query`가 날짜를 09-18로 고정해 09-19부터 실패, S8 무관). 실호출 1회(testwife 2026-12-31, API 경로, 원상복구 확인): 9.92초 타임아웃 → `fallback_prev`, `yesterday={routine: null, motion: null}` 기록 확인, 폴백이라 남편 알림 0건. 비용 약 $0.0038. `source=ai` 확인은 미완 |
| 2026-09-18 | S7 팁 역할 조정: 팁이 건강 가이드의 스트레칭 추천과 겹쳐("허리 스트레칭을 5~10분") 지시문을 "4종 가이드와 겹치지 않는 생활 행동 1개"로 변경(스트레칭·운동·메뉴·가사 분담·취침 제외). 스트레칭 영상은 건강 가이드 몫으로 새 단계 S_stretching_video 추가. `PROMPT_VERSION=2026-09-18.3`. 실호출(third, 원상복구): `source=ai` 6.70초, 팁 "허리 통증 완화를 위해 무거운 물건을 들 때 무릎을 구부려 올리세요."(38자). 비용 $0.0093. 테스트 174개 통과 |
| 2026-09-18 | S7 완료(커밋 전): 팁 전용 호출을 4종과 동시에 실행, 루틴 종료 후 최대 1초만 대기(`TIP_GRACE_SEC`), 팁 실패·지연·금지어는 `tip=null`이고 루틴은 `source=ai` 유지, 폴백은 `tip=null`. `PROMPT_VERSION=2026-09-18.2`. 실호출(third, 원상복구): `source=ai` 7.33초, 팁 "허리 통증이 있을 때는 허리 스트레칭을 5~10분 해보세요."(33자, source_ids 2개). 팁 호출 입력 3,268·출력 36 토큰으로 가장 빨리 끝나 전체 시간 영향 없음. 카테고리별 가사 2.49 / 수면 3.10 / 건강 3.70 / 식단 4.46초. 비용 $0.0086 |
| 2026-09-18 | S6 실호출 확인(third 계정, 원상복구 확인): 1회차 10.17초 타임아웃 → `fallback_template`($0.0051, 가사 키 미확인). 2회차 `source=ai` 6.96초, `prompt_version=2026-09-18.1`, 활동 4개(빨래·설거지·쓰레기 배출·강아지 산책) → `household:laundry`·`dishes`·`trash`·`custom` 규칙 통과, 제목은 라벨 그대로. 카테고리별: 가사 2.29초(출력 225) / 수면 3.08초(309) / 건강 3.87초(436) / **식단 5.77초(807)** → 가장 느린 호출은 식단(K1 개선 후보: 식단 출력 분량 제한). 2회차 $0.0077, 합계 $0.0128. 템플릿 가사 키 불일치는 K8 |
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
7. ~~S1~S3 수정분 커밋·push + 팀원에게 `routine_items.change_kind` 추가 공지~~ 완료(2026-09-18, `8b7b85a`·`423fcc4`)
8. ~~S4 이후는 §3 표 기준으로 진행. 결정1과 결정2의 완료 이력은 유지하되, 새 컨디션 수정 정책은 §2.5~2.8 및 S9·S10을 따른다. S2·S3의 `item_key`·revision 체계는 이어서 사용~~ 완료(2026-09-20, S4~S10 및 S_stretching_video·S_createroutine_loading. 남은 것은 S_date_modification·K1)

## 7. 남은 것 (요구사항 변경·알려진 문제)

### 7.1 요구사항 변경 (2026-09-17 흐름도 `02_AI하루루틴생성.mmd`, 04_1 개정)

| # | 요구 | 현재 | 단계 |
|---|---|---|---|
| R1 | ~~확정 후 컨디션 재입력 = 덮어쓰지 않고 새 루틴(FUC-W-COND-004), Daily 리포트는 날짜당 1개(NFR-028)~~ | ~~`daily_routines` 사용자·날짜당 1행 덮어쓰기, 확정 상태 없음~~ | ~~S3 완료(09-18): revision·confirmed_at·pg_cron 정리~~ |
| R2 | ~~확정 전 수정 = 루틴 재생성 + 남편 알림(FUC-W-COND-003, FUC-H-NOTI-002)~~ | ~~재생성 신호 없음, 완료 체크 유실~~ | ~~S2, S4 → S2·S4 완료(09-18): diff.py·change_summary·is_regeneration~~ |
| R3 | ~~AI 실패 → 실패 화면(W-CALLBACK-001) + 다시 시도 → 연속 실패 시 폴백~~ | ~~실패 즉시 폴백 저장 후 201~~ | ~~S5 완료(09-18): `docs/api.md` 'AI 실패 처리'~~ |
| R4 | ~~웰컴 카드 '오늘의 팁' 1개 AI 개인화(FUC-W-HOME-001)~~ | ~~출력 4종뿐~~ | ~~S7 완료(09-18): 팁 전용 호출, 실패 시 tip=null~~ |
| R5 | ~~입력에 전일 활동·홈캠 데이터~~ | ~~미포함~~ | ~~S8 완료(09-19): facts.yesterday(전일 루틴·모션 요약)~~ |
| R6 | ~~복수 컨디션 변경을 항목별로 해석하고 같은 가이드에 누적. 악화·호전은 상쇄하지 않으며 `mode`·`strength`·`direction`을 카테고리별로 산출~~ | ~~항목 하나의 최대 변화만 적용하는 방식으로는 허리·손목 동시 악화나 mixed 상태를 표현할 수 없음~~ | ~~S9 완료(09-19): impact_map.yaml·impact.py~~ |
| R7 | ~~컨디션 수정 시 관련 가이드만 이전 루틴 기준으로 TUNE/REPLAN, 무관한 가이드는 KEEP. 실제 예정 활동과 secondary 연관성, 카테고리별 실패 처리·병합·revision 반영~~ | ~~현행 4종 동시 재생성·전체 폴백 가정과 충돌. 최초 생성 경로는 유지~~ | ~~S10 완료(09-20): 수정 경로 실호출 확인~~ |

### 7.2 알려진 문제

| # | 문제 |
|---|---|
| K1 | NFR-001 p50 5초 **미달이지만 개선**(09-20): 식단 출력 제한(title 20자·reason/evidence 각 한 문장·태그 3개·주의 1개)으로 식단 출력 807→470토큰, 식단 호출 5.8→3.9초, 전체 중앙값 7.7→5.4초, 폴백 4/9→0/3. 남은 차이 0.4초는 모델 교체나 카테고리 축소 등 별도 검토. **범위 = 최초 전체 생성(4종 동시 호출)**. 컨디션 수정 경로는 대상 가이드만 불러 4.9~5.2초로 목표 안팎이라 대상이 아니다. 09-21 실측 전체 생성 9.97초(폴백 직전) — 변동 폭이 커 카테고리별 재측정 필요 |
| ~~K2~~ | ~~AI가 만든 `item_key`가 `breakfast_1` 형식(설계 `meal:lunch`)~~ → S1에서 고정 완료(09-18) |
| ~~K3~~ | ~~`daily_conditions.sleep_quality`·`LLM_FACT_KEYS`에 수면 값 잔존. 04_1 컨디션 입력 4종에 수면 없음~~ → 09-20 해소: 루틴 입력·전송(`CONDITION_COLUMNS`·`LLM_FACT_KEYS`)에서 제외. DB 컬럼은 Care 소유라 유지, Care 계약 테스트 1줄 수정 |
| ~~K4~~ | ~~컨디션 저장 API 없음 → 실제 앱에선 항상 409. 활동 코드표 9종(프론트 한글 라벨 vs 백엔드 코드) 확정 필요~~ → S6에서 해소(09-18): 저장 API는 팀원 구현분 사용, 코드표 확정 |
| ~~K5~~ | ~~날짜 기준 모션=UTC, 웬즈데이=KST~~ → S8에서 1안 적용(09-19): 모션 요약은 UTC 하루(어제 09:00~오늘 09:00 KST) 그대로 사용. Daily 리포트(care)와 같은 함수·같은 수치 |
| ~~K6~~ | ~~옛 요구사항 ID `W-ROUTINE-001/003`이 코드 주석·`backend/README.md`·`docs/api.md`·`fallback.yaml`·migration 주석에 남음 → `W-HOME-001`/`W-CALLBACK-001`~~ → 09-20 해소: 웬즈데이 소유 파일 7곳 정리. `docs/development/**`·`docs/backend/**`의 화면 ID는 팀원 문서라 손대지 않음 |
| K7 | MediaPipe 추론이 이벤트 루프 동기 점유 → 웬즈데이 응답 지연 위험. 마이그레이션 접두사 `20260916000000` 중복. **모션 담당 소유 영역(`app/services/movement/**`)이라 웬즈데이가 고치지 않는다 → 팀 공유 항목**(09-20) |
| ~~K8~~ | ~~기본 템플릿 가사 키(`household:light_only`, `household:partner_share`)가 S6 코드표 밖 → 폴백 뒤 AI 성공 시 가사 항목이 전부 삭제·추가로 잡힘. 처리 여부 미정~~ → 09-20 해소: 예정 활동이 있으면 폴백 가사 항목을 `household:<활동 코드>`로 만든다(`service.template_household`). 예정 활동이 없으면 기존 템플릿 유지 |
| ~~K9~~ | ~~재생성으로 빠진 항목을 지울 때 메뉴 수락·거절 기록도 함께 사라짐: `recommendation_feedback.routine_item_id`가 `on delete cascade`(`20260917010800` 8행). 09-18 팀원 구현으로 실제 데이터가 쌓이기 시작해 발생 가능. 해결안 = 피드백이 있는 항목은 삭제하지 않고 `change_kind='removed'`로 남기기. **Care 담당 회신 대기**(09-20 기록)~~ → 09-20 해소: `repository._sync_items`가 삭제 전 `recommendation_feedback`을 조회해 기록이 있는 항목은 `change_kind='removed'`로만 남긴다(조회 실패 시에도 지우지 않음). `docs/api.md`에 `removed` 항목은 오늘 루틴으로 표시하지 않는다는 계약 추가. 가이드 조회 API에서 제외할지는 Guide 담당과 협의 |
