# Backend Collaboration Rules

- 작성일: 2026-09-17 (STEP 6, 2026-09-17 2명 체제로 개정)
- 기준: `docs/backend/BACKEND_ARCHITECTURE.md`(팀 구성·소유권), `docs/backend/TARGET_DB_SCHEMA.md`(신규 테이블 계획).
- 목적: 2명이 동시에 migration·API를 추가할 때 충돌(특히 migration 충돌)을 막는다.
- **2026-09-18 개정(팀 합의)**: 보호(Protected) 대상은 모션 인식 테이블 `posture_calibration_profiles`·`posture_events`와 그 코드뿐이다. Routine AI(`daily_routines`·`routine_items`·`pregnancy_knowledge`, `app/services/routine/**`)는 **Routine AI 담당(웬즈데이 AI) 소유**로 바뀌어 담당자가 단독으로 변경할 수 있다 — 단, FK로 참조하는 테이블 소유자에게는 미리 알린다(§2.4). 이 날짜 이전에 쓴 문서·주석의 "Routine = Protected" 표현은 이 개정으로 대체된다.
- **개정 메모**: 원래 3명(User Context / Daily Experience / Relationship 각 1명) 기준으로 작성했으나, 인원이 2명으로 줄어 User Context와 Daily Experience를 Developer A 한 명이 맡도록 합쳤다. 화면 그룹 이름과 migration 파일명의 `<domain>` 태그(`user_context`/`daily_experience`/`relationship`/`shared`)는 인원 수와 무관한 분류라 바꾸지 않았다 — 아래 §2.1도 그대로 유지한다.

## 1. 팀 구성 요약

| 담당 | 화면 그룹 | 상세 |
|---|---|---|
| Developer A | User Context + Daily Experience | Profile, Condition, Calendar, Meal, Household, Health, Sleep, Record, Report |
| Developer B | Relationship / Integration | Family, Invitation, Join, Notification, Chat, Frontend API Integration |
| Routine AI 담당 | Routine AI(웬즈데이 AI) | `daily_routines`, `routine_items`, `pregnancy_knowledge`, `app/services/routine/**`, `app/api/v1/routine.py` — 담당자 단독 변경 가능 |
| Protected | 모션 담당 합의 필요 | Movement Recognition(`posture_calibration_profiles`, `posture_events`, `app/services/movement/**`, `app/api/v1/movement.py`, `backend/models/**`), Auth(`auth.users`, `core/security.py`) |

전체 배분 근거와 현재 파일 구조와의 불일치(계정/케어/패밀리 파일이 새 경계와 어긋나는 부분)는 `BACKEND_ARCHITECTURE.md` §2를 먼저 읽는다.

## 2. Migration 규칙

### 2.1 파일명

```text
YYYYMMDDHHMMSS_<domain>_<purpose>.sql
```

- `<domain>`: `user_context` / `daily_experience` / `relationship` / `shared` 중 하나(새 배분 기준을 그대로 쓴다 — 기존 `account`/`care`/`family` 이름은 새로 만드는 migration에 쓰지 않는다)
- `<purpose>`: 그 migration이 하는 일 하나만, 동사 없이 명사구로(예: `partner_links`, `household_requests`, `notifications`)
- 예: `20260918090000_relationship_partner_links.sql`, `20260918091500_daily_experience_household_requests.sql`, `20260918093000_user_context_profiles_role.sql`

### 2.2 한 PR = 한 migration = 한 목적

- migration 파일 하나는 **테이블 하나(또는 그 테이블에 강하게 종속된 인덱스·제약)만** 만든다. 예: `household_requests`와 `household_request_items`처럼 부모-자식으로 반드시 함께 필요한 경우만 예외적으로 한 파일에 묶고, 그 외에는 테이블마다 별도 migration으로 쪼갠다.
- 관련이 있어 보여도 목적이 다르면(예: "notifications 테이블 생성"과 "household_requests에 컬럼 추가") 반드시 다른 PR·다른 migration 파일로 낸다.
- 하나의 PR 안에서 여러 담당 영역의 테이블을 동시에 만들지 않는다(Developer A의 PR이 `household_requests`와 Developer B의 `notifications`를 한 번에 만들지 않는다).

### 2.3 기존 migration은 절대 수정하지 않는다

- `supabase/migrations/*.sql`의 기존 파일(2026-09-18 기준 15개, `20260915000000`~`20260917010800`)은 내용이 잘못됐다고 판단되더라도 직접 고치지 않는다.
- 기존 migration 주석 중 "`routine_items`는 Protected 테이블"(`20260917010300`·`010700`·`010800`)은 2026-09-18 개정 전 표현이다. 이 규칙에 따라 파일은 고치지 않고 이 문서가 우선한다.
- 컬럼을 더하거나 제약을 바꿔야 하면 새 migration(`ALTER TABLE ... ADD COLUMN ...`, `ALTER TABLE ... DROP CONSTRAINT ...` 등)으로 남긴다 — 기존 `20260916000000_relax_due_date_constraint.sql`이 이미 이 패턴을 보여준다(제약을 나중에 별도 파일로 제거).

### 2.4 보호(Protected) 테이블 변경은 단독 임의 변경 금지

다음 테이블에 대한 migration은 **모션 인식 담당(Auth는 나머지 한 명)의 리뷰 승인**을 PR 머지 전에 받는다(2026-09-18 개정으로 범위 축소):

- `posture_calibration_profiles`, `posture_events`(Movement Recognition 소관 — 모션 인식 카메라 테이블)
- `auth.users`에 영향을 주는 모든 변경(Auth 소관)

Routine AI 테이블(`daily_routines`, `routine_items`, `pregnancy_knowledge`)은 보호 대상이 아니다. Routine AI 담당이 단독으로 migration을 낼 수 있으며, 대신 `routine_items`를 FK로 참조하는 테이블(`household_request_items`, `chat_messages`, `recommendation_feedback`)에 영향이 있으면 PR 설명에 적고 그 소유자에게 미리 알린다. `motion_consents`도 보호 대상이 아니다(카메라 테이블이 아닌 동의 설정값).

다른 담당자의 테이블을 **FK로 참조만** 하는 것은 이 규칙 대상이 아니다(예: Developer A가 `household_request_items.routine_item_id → routine_items(id)` FK를 추가하는 것은 `household_request_items`가 A 소유 테이블이므로 A가 단독으로 migration을 내도 된다 — `routine_items` 자체를 변경하는 것이 아니기 때문이다). 다만 참조 대상 테이블의 PK 타입·존재를 반드시 최신 migration 기준으로 확인한다.

### 2.5 순서·충돌 방지 실무 규칙

- migration을 추가하는 PR은 머지 직전에 `main`을 기준으로 rebase해 타임스탬프가 실제 적용 순서와 어긋나지 않게 한다.
- 같은 날 여러 명이 migration을 낼 경우, PR을 올릴 때 타임스탬프를 **현재 시각 그대로** 쓰고, 머지 순서가 뒤바뀌면(예: 늦게 만든 PR이 먼저 머지됨) 머지 직전에 타임스탬프를 다시 갱신해 실제 적용 순서와 파일명 순서를 일치시킨다.
- 신규 테이블은 기존 컨벤션을 따른다: `create table if not exists`, PK `uuid default gen_random_uuid()`(단, `notifications`처럼 이미 계획에 없는 예외가 생기면 `TARGET_DB_SCHEMA.md`를 먼저 갱신), RLS 활성화 + 정책 없음(service role 전용 접근).

## 3. API / 코드 파일 규칙

### 3.1 신규 API는 새 배분 기준 파일에 만든다

`API_CONTRACT.md`의 `[planned]` 8개 API부터는 기존 `account.py`/`care.py`/`family.py`에 추가하지 않는다. 아직 `BACKEND_ARCHITECTURE.md` §4의 목표 파일(`personal_experience.py`/`relationship.py`)이 없다면, 해당 담당자가 자신의 첫 신규 API를 낼 때 그 파일을 새로 만들고 `main.py`에 라우터를 등록한다(기존 `account`/`care`/`family` 라우터는 그대로 둔 채 병행).

### 3.2 기존 Stub 파일을 건드릴 때

- `account.py`/`care.py`/`family.py`의 기존 엔드포인트를 Supabase adapter로 교체하는 PR은 **자신이 소유한 엔드포인트만** 골라서 낸다(`BACKEND_ARCHITECTURE.md` §2 표에서 파일별로 어떤 엔드포인트가 누구 소유인지 확인).
- 같은 파일의 다른 담당자 소유 엔드포인트는 건드리지 않는다. 부득이하게 공용 코드(예: 파일 상단의 `router = APIRouter(...)`, 공용 `_repository` 인스턴스 선언)를 바꿔야 하면, 그 파일에 걸쳐 있는 모든 담당자에게 리뷰를 요청한다.
- 한 파일 안에서 담당이 갈리는 상황이 PR 충돌을 자주 일으키면, 그 시점에 §3.3의 "구조 전용 PR"로 파일을 쪼갠다 — 억지로 계속 한 파일에 유지하지 않는다.

### 3.3 구조 전용 PR(파일 분리)

- 기능 추가와 파일 이동(리팩터)을 같은 PR에 섞지 않는다.
- 파일을 쪼개는 PR은 그 파일에 걸쳐 있던 모든 담당자의 승인을 받는다.
- 파일 분리 PR은 동작 변경이 없어야 한다(같은 엔드포인트, 같은 응답 — 위치만 이동). 동작 변경이 필요하면 분리 PR 이후 별도 PR로 낸다.

## 4. 리뷰 체크리스트(migration PR)

머지 전 아래를 확인한다:

- [ ] migration 파일이 `YYYYMMDDHHMMSS_<domain>_<purpose>.sql` 형식이다
- [ ] 한 PR에 한 목적(테이블 하나, 또는 부모-자식 쌍)만 있다
- [ ] 기존 migration 파일을 수정하지 않았다(새 파일만 추가)
- [ ] 보호 테이블(§2.4: `posture_*` 2개, `auth.users`)을 변경한다면 관련 승인자 리뷰가 있다
- [ ] `routine_items` 등 다른 테이블이 FK로 참조하는 테이블을 바꾼다면 참조하는 쪽 소유자에게 알렸다
- [ ] `create table if not exists`, RLS 활성화(정책 없음) 컨벤션을 따른다
- [ ] `TARGET_DB_SCHEMA.md`에 이미 계획된 테이블이면 그 컬럼 정의와 일치한다(불일치 시 먼저 `TARGET_DB_SCHEMA.md`를 갱신하는 PR을 낸다)

## 5. 참고 문서

- `docs/backend/BACKEND_ARCHITECTURE.md` — 담당 배분과 근거
- `docs/backend/TARGET_DB_SCHEMA.md` — 신규 테이블 계획(컬럼·PK·FK·RLS)
- `docs/backend/API_CONTRACT.md` / `API_IMPLEMENTATION_MATRIX.md` — API별 상태·소유
- `backend/DOMAIN_OWNERSHIP.md` — 기존(구) 3분할 기준. 이번 문서의 새 배분과 다르므로 신규 작업은 이 문서가 아니라 `BACKEND_ARCHITECTURE.md`를 따른다.
