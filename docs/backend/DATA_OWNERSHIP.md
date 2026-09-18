# Data Ownership & Source of Truth

- 작성일: 2026-09-17 (STEP 2)
- 목적: 화면 DB스키마(PDF)와 기존 DB(실제 migration)와 `docs/backend/TARGET_DB_SCHEMA.md`를 기준으로 데이터별 source-of-truth를 정의해, 같은 데이터가 여러 테이블에 중복 관리되지 않도록 한다.
- 기준: `docs/backend/TARGET_DB_SCHEMA.md`(MVP 목표 스키마), `supabase/migrations/*.sql`(실제 적용 7개 테이블), `docs/backend/BACKEND_STATUS.md`(화면-FUC-DB-API 매트릭스), `docs/backend/DB_SCHEMA_RECONCILIATION.md`.
- 이 단계에서는 코드·migration을 변경하지 않는다.

## 분류 기준

- **SOURCE**: 그 데이터의 유일한 원본 저장소. 다른 어떤 테이블도 같은 값을 복제 저장하지 않는다.
- **DERIVED**: 저장하지 않고 SOURCE를 조회 시점에 계산·가공해서 만든다.
- **CACHE**: SOURCE(들)를 특정 시점에 한 번 집계해 별도로 고정 저장한 값. SOURCE가 이후 바뀌거나(재계산) 만료·삭제돼도 CACHE는 남는다(스냅샷).
- **EVENT**: 특정 시점에 발생한 사건 자체를 행 단위로 남긴다(집계 대상이지 최신 상태를 덮어쓰지 않음).
- **VIEW**: 저장 없이 SOURCE를 다른 Actor(주로 남편) 권한 범위로 필터링해 보여주는 읽기 전용 조합.

---

## Data Ownership Matrix

| Data | Domain | Source Table | Consumer | Type | Notes |
|---|---|---|---|---|---|
| 프로필 1~2단계(출산예정일/마지막생리/신장/체중) | Profile | `pregnancy_profiles` | W-PROFILE-001/002, W-HOME-001, W-MEAL-002, W-MENU-001 | SOURCE | Supabase 연동 완료(IMPLEMENTED) |
| 프로필 3~6단계(초산경산/단태쌍태/알레르기/주의진단) | Profile | `pregnancy_profiles`(컬럼 존재) | W-PROFILE-003~007, W-MEAL-002 | SOURCE | 컬럼은 있으나 단계별 저장 API 없음(SKELETON_REQUIRED) |
| 임신 주수·일수 | Profile | — | W-HOME-001, H-REPORT-001, W-MENU-001 | DERIVED | `due_date - 280일` 기준 조회 시점 계산, 저장 안 함 |
| 역할(role)·표시 이름 | Profile | `profiles`(MISSING) | B-ENTRY-001, W-MENU-001, 알림 발신자 표시 | SOURCE | 신규 테이블 필요 |
| 당일 컨디션 7종 + 예정 활동 | Condition | `daily_conditions` | W-COND-001, W-TASK-001, 루틴 생성 입력 | SOURCE | 원문은 남편에게 비노출(NFR-013) |
| 컨디션 4단계 지수(좋음/보통/나쁨/힘듦) | Condition | — | B-CAL-001, H-REPORT-001 | DERIVED | `daily_conditions` 점수 기준 계산, 계산식 자체는 미확정(TBD) |
| 하루 루틴 생성 원본(source/model/request_payload/response) | Routine | `daily_routines` | W-HOME-001, W-CALLBACK-001 | SOURCE | Protected, 실동작 |
| 루틴 항목(카테고리별 payload/status/completed_by) | Routine Item | `routine_items` | Meal/Household/Health/Sleep/Record 전 도메인의 공통 원본 | SOURCE | Protected. 다른 도메인은 `category`로 필터링해서 소비하며 복제 저장 금지 |
| 식사 가이드 표시(끼니·메뉴·영양태그) | Meal | `routine_items`(category=meal) | W-MEAL-001, W-MEAL-002 | DERIVED | 자체 테이블 불필요 |
| 메뉴 수락/거절/재요청 이력 | Meal | `recommendation_feedback`(MISSING) | W-MEAL-002, W-CHAT-001 | SOURCE | 신규 테이블, NFR-014(이력 최소 항목) |
| 가사 3분류 표시(직접/가전/가족) | Household | `routine_items`(category=household) | W-HOUSE-001 | DERIVED | 자체 테이블 불필요 |
| 가사 요청(이유·상태 전이) | Household | `household_requests`(MISSING) | W-HOUSE-001, H-REQUEST-001 | SOURCE | 신규 테이블. 아내가 쓰고 남편이 상태를 갱신하는 양방향 공유 SOURCE(복제 아님) |
| 가사 요청 항목 | Household | `household_request_items`(MISSING) | 위와 동일 | SOURCE | `routine_item_id`로 `routine_items` FK 재사용 — 항목 제목/설명 원본 복제 금지 |
| 건강 가이드 표시(부위·활동·소요시간) | Health | `routine_items`(category=health) | W-HEALTH-001 | DERIVED | 자체 테이블 불필요 |
| 수면 가이드 표시(취침시간·환경 5항목) | Sleep | `routine_items`(category=sleep) | W-SLEEP-001 | DERIVED | 자체 테이블 불필요 |
| 수면 환경 override 이력 | Sleep | `recommendation_feedback`(kind=sleep_env_override) | W-SLEEP-001 팝업 | SOURCE | Meal 이력과 테이블 공유 — 도메인별 별도 이력 테이블 생성 금지 |
| 실행 기록(완료/취소, 수행 주체) | Record | `routine_items.status/completed_by/completed_at` | W-RECORD-001, W-HEALTH-002, W-REPORT-001 | SOURCE | 별도 execution 로그 테이블을 만들지 않음 — `routine_items` 자체가 기록 |
| Daily 리포트(확정 집계) | Report | `daily_reports`(MISSING) | W-REPORT-001, H-REPORT-001(파생) | SOURCE(확정 시점 스냅샷) | NFR-028: 날짜당 1개 unique. `content`는 확정 시점에 다른 SOURCE를 한 번 집계해 고정 |
| 오전 리포트 | Report | `daily_reports`(kind=morning) 또는 `daily_conditions`+`routine_items` 실시간 파생 | H-REPORT-001 | DERIVED | `daily_reports`와 별개 테이블을 만들지 않고 `kind` 컬럼으로 통합(구 ERD 초안(삭제됨)과 동일) |
| 캘린더 월간 조회 | Calendar | `daily_conditions` + `routine_items` + `daily_reports`(조회 조합) | B-CAL-001 | VIEW | 저장 테이블 없음 — 신규 Calendar 테이블 생성 금지 |
| 파트너 연동 상태 | Family | `partner_links`(MISSING) | B-ENTRY-001, W-MENU-001, 남편 접근 권한 판단 전체 | SOURCE | 신규 테이블, `unique(husband_user_id)`로 중복 연동 방지 |
| 초대 토큰 | Family | `partner_invitations`(MISSING) | W-INVITE-001, B-ENTRY-001(남편) | SOURCE | 신규 테이블, NFR-026(72시간·1회성) |
| 알림(오전리포트/가사요청/컨디션변경) | Notification | `notifications`(MISSING) | H-NOTI-001 | EVENT | 트리거 발생 시점마다 행 생성, 상태 변경이 새 알림을 만들지 않음(`DOMAIN_OWNERSHIP.md` 원칙) |
| 챗봇 대화 이력 | Chat | `chat_messages`(MISSING) | W-CHAT-001 | SOURCE | NFR-027: 원문은 Report에 반영 안 함, 보관·파기 기준 TBD |
| 임계 이벤트(자세·부담라벨·지속시간) | Movement | `posture_events` | B-MOTION-001, W-REPORT-002 | EVENT | "위험한 순간만 저장" 원칙 — `burden_label='Normal'` 행 없음. Protected |
| 자세 기준선(캘리브레이션) | Movement | `posture_calibration_profiles` | `WS /movement/live/stream` 캘리브레이션 단계 | SOURCE | 최신 1행을 현재 기준선으로 사용. Protected |
| 모션 동의·수집 ON/OFF | Movement | `motion_consents`(MISSING) | B-MOTION-001 | SOURCE | 신규 테이블. 현재 WS 연결 게이트와 미연동 |
| 모션 일일 요약(관절 부담) | Movement | — (`posture_events` 집계) | W-REPORT-002, `daily_reports.content` | DERIVED / 확정 시 CACHE | `daily_reports` 확정 시점에 한해 스냅샷으로 고정 저장 — `posture_events` 30일 삭제 후에도 리포트에는 남음 |
| 모션 세션 상태(진행 중 세션) | Movement | `motion_sessions`(MISSING, 현재는 프로세스 메모리) | `GET /movement/live` | CACHE | 서버 재시작 시 소실, 다중 사용자 미지원. 도입 여부는 `TARGET_DB_SCHEMA.md`에서 NOT_REQUIRED(이번 MVP) |

---

## Duplicate Storage To Avoid

화면 DB스키마(PDF)가 화면별로 필드를 서술하고 있어 화면마다 전용 테이블을 만들고 싶어지기 쉽지만, 아래는 이미 다른 SOURCE로 해결 가능하므로 신규 테이블을 만들지 않는다.

1. **컨디션 원본을 남편용 알림/리포트 테이블에 복제 저장하지 않는다.** `daily_conditions`가 SOURCE이고, 남편에게는 `daily_reports`/`notifications`를 통해 허용된 요약만 DERIVED로 내려준다.
2. **루틴 항목을 카테고리별(식사/가사/건강/수면) 별도 테이블로 쪼개지 않는다.** `routine_items` 하나를 `category` 컬럼으로 구분해 공용 SOURCE로 유지한다(Protected 모듈, 이미 이렇게 구현됨).
3. **실행 기록을 `routine_items`와 별도의 execution 로그 테이블로 분리하지 않는다.** `status`/`completed_by`/`completed_at` 컬럼이 이미 있어 이를 갱신하는 것으로 충분하다. `care.py`의 Stub이 `RoutineExecutionResponse`를 별도 메모리 상태로 관리하는 현재 구조는 실제 구현 시 `routine_items` 갱신으로 교체해야 한다.
4. **캘린더 전용 저장 테이블을 만들지 않는다.** `daily_conditions`/`routine_items`/`daily_reports` 조회 조합(VIEW)으로 처리한다(이미 이렇게 설계됨).
5. **가사 요청 항목에 제목·설명을 복제 저장하지 않는다.** `household_request_items.routine_item_id`가 `routine_items`를 FK로 재사용하도록 설계돼 있다.
6. **모션 요약을 상시 별도 요약 테이블에 저장하지 않는다.** `posture_events`가 SOURCE이고, `daily_reports` 확정 시점에만 스냅샷을 남긴다(그 외에는 매번 계산).
7. **메뉴 재추천 이력과 수면 환경 override 이력을 도메인별 별도 테이블(`meal_feedback`, `sleep_feedback` 등)로 나누지 않는다.** `recommendation_feedback` 하나를 `kind` 컬럼(`meal_accept`/`meal_reject`/`meal_replace`/`sleep_env_override`)으로 구분해 공용 SOURCE로 쓴다.
8. **프로필을 두 곳에 별도 형태로 저장하지 않는다.** `account.py`의 Stub(`PUT /account/profile`, 6단계 일괄·`birth_date` 요구)과 `profile.py`(Supabase, 1~2단계 단계별)는 같은 `pregnancy_profiles`를 대상으로 해야 한다. 최신 FUC-W-PROFILE-002가 `birth_date`를 필수로 확정했으므로 migration으로 컬럼을 추가하고 두 계약을 하나로 통합한다.

## Derived Data

저장하지 않고 조회 시점에 계산하는 데이터 목록:

- 임신 주수·일수 (`pregnancy_profiles.due_date` 기준)
- 컨디션 4단계 지수 (`daily_conditions` 점수 기준, 계산식 TBD)
- 식사/가사/건강/수면 가이드 화면 표시값 (`routine_items` category 필터)
- 오전 리포트 요약 (실시간 파생 버전을 택할 경우 `daily_conditions`+`routine_items`)
- 캘린더 월간 뷰 (`daily_conditions`+`routine_items`+`daily_reports` 조합)
- 모션 일일 요약(관절 부담) — `daily_reports` 확정 전까지는 매번 `posture_events` 집계로 계산(CACHE 아님), 확정 시점에만 스냅샷으로 고정

## Husband Shared Views

남편에게 노출되는 데이터는 모두 **별도 복사 테이블이 아니라 `partner_links`로 확인한 아내 `user_id` + 화면별 허용 범위로 필터링한 조회**로 구현한다.

| 화면 | 조회 대상 SOURCE | 조회 방식 |
|---|---|---|
| H-REPORT-001 (오전 리포트) | `daily_conditions`, `routine_items`, `daily_reports` | `partner_links`에서 남편의 `wife_user_id` 확인 → 허용 필드만 조합해 응답(원문 미노출) |
| W-REPORT-001 "남편에게 공유" | `daily_reports` | 같은 행을 남편 role로 조회(복제 없음), `shared_at` 이후에만 노출 |
| B-CAL-001 (남편 캘린더) | `daily_conditions`+`routine_items`+`daily_reports` VIEW | 남편은 읽기 전용 — 수정 API 자체를 노출하지 않음(화면설계서 명시) |
| B-MOTION-001 (남편 조회) | `posture_events` | 남편은 조회만, ON/OFF·동의 철회 API는 아내 전용으로 분리 |
| H-REQUEST-001~003 (가사 요청) | `household_requests`/`household_request_items` | 예외적으로 남편이 상태를 직접 갱신하는 **양방향 SOURCE** — 뷰가 아니라 같은 행을 부부가 함께 쓴다. 단, 이 경우에도 요청 원본은 하나이며 남편용 사본을 만들지 않는다 |
| H-NOTI-001 (알림) | `notifications` | `recipient_user_id`로 직접 필터(EVENT 테이블 자체가 수신자별로 나뉨, 뷰가 아니라 별도 행) |

`DOMAIN_OWNERSHIP.md`가 이미 명시한 남편 공유 범위(오전 리포트·Daily 리포트·가사 요청·홈캠 공유 정보·캘린더)를 벗어나는 데이터(프로필 원본, 컨디션 원본, AI 대화 원문)는 Family 응답 Schema 자체에 필드를 만들지 않는다 — 조회 자체를 막는 것이 필터링보다 우선이다.

## Sensitive Data

NFR-008(민감정보 암호화)·NFR-010(민감정보 분리 관리)·NFR-013(남편 공유 범위 제한) 적용 대상:

- `daily_conditions`의 7종 점수 원본 — 남편 Family 응답 스키마에 필드 자체를 넣지 않는다
- `pregnancy_profiles.allergies/medical_conditions/medical_note` — AI 입력에는 사용하되 남편에게는 비노출
- `posture_events`의 자세 각도·부담 라벨 원본 — 남편에게는 집계된 알림 리스트만, 프레임/영상은 애초에 저장하지 않음(NFR-011)
- `chat_messages.content` — 개인화 목적으로만 재사용, Daily 리포트에 원문 미반영(NFR-027)
- 컬럼 단위 암호화(Vault/pgsodium) 적용 여부는 구 ERD 초안(삭제됨)에서 "결정 보류"였던 TBD — 이번 문서에서도 새로 결정하지 않음

## AI Data Boundary

- AI(OpenAI, `app/services/routine/**`)는 **읽기**: `pregnancy_profiles`, `daily_conditions`, `pregnancy_knowledge`(RAG 코퍼스)만 최소 항목으로 조회한다(NFR-014, `daily_routines.request_payload`에 감사 기록).
- AI는 **쓰기**: `daily_routines`, `routine_items`(및 실 구현 시 `chat_messages`)에만 결과를 저장한다.
- AI는 사용자가 직접 입력한 SOURCE(`pregnancy_profiles`, `daily_conditions`)를 절대 직접 수정하지 않는다 — AI 결과와 사용자 원본 입력이 같은 테이블에서 뒤섞이지 않도록 분리를 유지한다.
- `routine_items.source_ids`(RAG 근거 `pregnancy_knowledge.id`)는 AI 출력의 파생 메타데이터이며 `pregnancy_knowledge` 원본을 복제하지 않는다.
- 이 경계는 Protected 모듈(`app/services/routine/**`) 내부 구현이라 이번 단계에서 코드를 확인만 했고 변경하지 않았다.

## Movement Data Boundary

- 원본 영상, 프레임, 33-landmark 좌표는 **어떤 테이블에도 저장하지 않는다**(NFR-011, `schemas/movement.py` 결정 그대로 유지). 이 경계는 신규 데이터 설계에서도 재확인했고 예외를 두지 않는다.
- `posture_events`(EVENT)와 `posture_calibration_profiles`(SOURCE)만 Movement 도메인의 영속 데이터이며, 둘 다 `app/services/movement/**`(Protected)만 쓴다.
- 다른 도메인(Report/Notification/Family)은 이 두 테이블을 **읽기 전용**으로만 소비하고, 자체 테이블에 원본 이벤트를 복제하지 않는다 — 유일한 예외는 `daily_reports.content`의 모션 요약 스냅샷이며, 이는 `posture_events`의 30일 보존 만료 이후에도 과거 리포트 조회를 지원하기 위한 의도된 예외로 이미 설계돼 있다(중복 저장 위험이 아님, `DB_SCHEMA_RECONCILIATION.md` 확인 완료).
- `motion_sessions` 도입 여부(현재는 프로세스 메모리 `_current_session_id`)는 Protected 모듈 변경이 필요해 이번 단계에서 결정하지 않고 TBD로 남긴다.

**STEP 14 재확인**: `motion_consents`(STEP 7 신규 스키마)를 현재 Movement 구현과 비교했다. `posture_events`/`posture_calibration_profiles`(Protected)는 이미 `EventStore` Protocol(`app/services/movement/events.py`) + `InMemoryEventStore`(Demo 계속 사용 가능) + `SupabaseEventStore`(별도 Adapter) 구조를 갖추고 있어 — 이번 STEP이 요구한 "필요하다면 MovementEventRepository 경계만 추가"에 이미 해당해 새로 만들지 않았다. `motion_consents`(설정값, 이벤트 아님)만 STEP 14에서 `app/domains/family/supabase_repository.py`에 실 연결했고, 저장 필드는 `consent_granted`/`collection_enabled`/`updated_at` 3개뿐 — 카메라 프레임·영상·landmark는 어디에도 없다(회귀 테스트: `tests/test_family_motion_consent.py`). 알고리즘(`rule_engine.py` 등)과 Protected 스키마는 수정하지 않았다.

## Husband Data & Permission (STEP 13)

남편 화면설계서(B-ENTRY-001, B-CAL-001, H-NOTI-001, H-REPORT-001, H-REQUEST-001/002, B-MOTION-001)와 남편 화면 DB 스키마(실은 화면 필드 서술 — STEP 0에서 이미 확인, 실제 테이블 정의 없음)를 다시 대조해 데이터를 4분류했다.

| 데이터 | 화면 | 분류 | Source | 비고 |
|---|---|---|---|---|
| 남편 본인 role·표시 이름 | B-ENTRY-001, 전역 | **OWNED BY HUSBAND** | `profiles`(user_id=남편) | 초대 수락(`link_partner`) 시점에 `role='husband'`로 처음 생성됨(STEP 13) |
| 알림 수신함 | H-NOTI-001 | **OWNED BY HUSBAND** | `notifications`(recipient_user_id=남편) | 본인만 보는 이벤트 로그. 아직 Stub(별도 STEP) |
| 초대 토큰 검증·연동 상태 | B-ENTRY-001(수락) | **OWNED BY HUSBAND**(수락 행위) / 관계는 공유 | `partner_invitations`, `partner_links` | 토큰은 아내가 발급하지만 "이 초대를 쓸지"는 남편의 행위 — STEP 13에서 실 연결 |
| 가사 요청 | H-REQUEST-001/002 | **SHARED / event**(양방향 쓰기) | `household_requests`(+`items`) | 아내가 만들고 남편이 상태를 전이(요청됨→확인됨→완료됨) — 어느 한쪽 소유가 아니라 같은 행을 공유. 아직 Stub |
| 오전 리포트 | H-REPORT-001 | **SHARED projection** | `partner_links`(authorization) → `pregnancy_profiles`+`daily_conditions`+`routine_items`(그 자리에서 읽음) | STEP 12에서 구현 완료. 남편용 복제 테이블 없음 |
| 캘린더(읽기 전용) | B-CAL-001 | **SHARED projection**(예정) | `daily_conditions`+`daily_reports` | STEP 12에서 아내용은 구현, 남편 role 필터링(수정 금지)은 아직 없음 — TBD |
| 홈캠 조회(읽기 전용) | B-MOTION-001(남편) | **SHARED projection**(예정) | `posture_events` | 아직 남편 role 조회 권한 분기 없음 — TBD |
| 임신 주수 | H-REPORT-001 | **DERIVED** | `pregnancy_profiles.due_date` 기준 계산 | 저장 안 함 |
| 진입 목적지(destination) | B-ENTRY-001 | **DERIVED** | role+profile+partner_link 조합 계산 | 저장 안 함 |
| 아내 Profile 원본 | (없음 — 남편 화면에 노출 필드 자체가 없음) | **NOT ACCESSIBLE** | `pregnancy_profiles`(원본) | `profile.py`/`account.py` 어떤 엔드포인트도 타 user_id로 조회 불가(STEP 10 테스트로 확인) |
| 컨디션 원본 점수(1~5) | (없음) | **NOT ACCESSIBLE** | `daily_conditions`(원본) | 오전 리포트는 "높음" 같은 정성 문구로만 요약(STEP 12) |
| AI 대화 원문 | (없음) | **NOT ACCESSIBLE** | `chat_messages` | Family 응답 Schema 자체에 필드 없음 |

### 관계 테이블 기반 접근권한 검증 (구현 완료, STEP 13)

- `partner_links`가 유일한 관계 SOURCE다. `husband_*` 복제 테이블은 만들지 않았다 — 남편에게 보여줄 데이터는 전부 위 표처럼 아내 테이블을 그 자리에서 읽는 projection이다.
- 초대 수락(`AccountService.accept_invitation`)은 STEP 13에서 실제 DB(`partner_invitations`/`partner_links`)에 연결했다. 순서를 **연동 시도 → 성공 시에만 토큰 소진**으로 바로잡았다(기존 순서는 연동이 실패해도 토큰이 먼저 소진되는 버그였음 — STEP 13에서 발견·수정).
- 초대 링크는 `partner_invitations_max_72h` CHECK 제약(STEP 7 migration)으로 72시간 이내만 허용되고, `used_at` 컬럼으로 1회성을 강제한다 — 서비스 계층도 `used_at is not None`이면 409로 거절한다.
- `partner_links.husband_user_id`의 `unique` 제약으로 "이미 다른 아내와 연동된 남편"을 DB 레벨에서 막고, Repository가 이를 감지해 503이 아니라 409(DomainConflictError)로 명확히 알린다.
- 가사 요청 확인(`family/service.py`의 `_partner_request`)과 오전 리포트 조회 모두 같은 원칙 — `partner_links`(또는 요청 소유자 목록)로 권한을 검증한 뒤에만 데이터를 보여준다.

### 명시적으로 추가하지 않은 기능

기능요구사항명세서·유스케이스 어디에도 없는 다음 기능은 이번 STEP은 물론 이전 STEP에서도 추가하지 않았다(`test_account_partner_link.py::test_no_unlink_reject_or_auto_reject_endpoints_exist`로 회귀 검증):

- 연동 해제(unlink/disconnect)
- 가사 요청 거절(reject/decline) — `HouseholdRequestStatus`는 `unconfirmed/confirmed/completed` 3종뿐, 거절 상태 자체가 없음(`DOMAIN_OWNERSHIP.md`가 이미 "가사 요청에는 거절 상태가 없다"로 명시)
- 초대 자동 거절(auto-reject)
