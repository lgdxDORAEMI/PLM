# Target DB Schema (MVP)

- 작성일: 2026-09-17 (STEP 4)
- 목적: (1) 아내/남편 화면 DB 스키마, (2) 실제 Supabase migration, (3) 실제 Backend 코드가 사용 중인 데이터를 3-way 비교하고, 이번 MVP의 Target DB Schema를 정의한다.
- 이 문서는 **설계 문서**이며 migration 파일을 생성하지 않는다. 기존 migration은 수정하지 않는다. 필요한 신규 테이블만 "계획"으로 남긴다.
- Routine/AI 구조(`daily_routines`/`routine_items`/`pregnancy_knowledge`)는 이 문서에서 재설계하지 않는다 — Routine AI 담당(웬즈데이 AI) 소유다(2026-09-18 개정으로 Protected에서 제외). 재생성 이력 요구(FUC-W-COND-003/004)에 따른 변경은 Routine AI 담당이 `docs/ai_wednesday/Ai_wednesday_pipeline_v3.md` §3 S3로 진행한다.

## 3-way 비교 요약

| Table | 화면 DB스키마 PDF(아내/남편) | 실제 Supabase Migration | 실제 Backend 코드 사용 | 분류 |
|---|---|---|---|---|
| `pregnancy_profiles` | 아내 PDF W-PROFILE-001~007 필드 서술과 일치(단, PDF는 테이블 정의가 아니라 화면 필드 서술) | **존재** — `20260915000000` + `20260916000000_relax_due_date_constraint` + `20260917000001`(3~6단계 컬럼) | `profile_service.py`(1~2단계 실사용), `account` Stub(6단계 개념 참조, 미영속) | **KEEP** |
| `daily_conditions` | 아내 PDF W-COND-001/W-TASK-001 필드 서술과 일치 | **존재** — `20260917000001` | `care` Stub이 메모리로만 사용, 테이블 미연결 | **KEEP** |
| `daily_routines` | PDF에 직접 서술 없음(화면 표시는 `routine_items` 경유), FUC 기준 설계 | **존재** — `20260917000001` | `routine.py` 실사용(Routine AI 소유) | **KEEP** |
| `routine_items` | 아내 PDF W-MEAL/HOUSE/HEALTH/SLEEP 필드 서술과 일치("계산 데이터"로 표기) | **존재**(`source_ids` 컬럼 포함, `20260917000001`) | `routine.py` 실사용(Routine AI 소유) | **KEEP** |
| `pregnancy_knowledge` | PDF에 없음(RAG 내부 코퍼스, 화면 비노출) | **존재**(pgvector, `20260917000000`) | `routine/retriever.py` 실사용(Routine AI 소유) | **KEEP** |
| `posture_calibration_profiles` | 아내/남편 PDF B-MOTION-001 서술과 대략 일치 | **존재**(`20260916000000_create_movement_tables`) — 구 ERD 초안(삭제됨)의 명칭(`posture_calibrations`)과 실제 테이블명이 달랐음 | `movement.py` 실사용(**Protected**) | **KEEP** |
| `posture_events` | 아내/남편 PDF B-MOTION-001 서술과 일치 | **존재**(`20260916000000_create_movement_tables`) | `movement.py` 실사용(**Protected**) | **KEEP** |
| `profiles` | 아내 PDF에 role 개념 없음(구 ERD 초안(삭제됨) 자체 제안) | 없음 | `account` Stub이 `AccountState.role` 개념만 참조, 미영속 | **NEW** |
| `partner_invitations` | 아내 PDF W-INVITE-001 서술과 일치 | 없음 | `account` Stub 메모리만 | **NEW** |
| `partner_links` | 아내/남편 PDF 연동 상태 서술과 일치 | 없음 | `account` Stub 메모리만 | **NEW** |
| `household_requests` | 아내/남편 PDF W-HOUSE-001/H-REQUEST-001 서술과 일치 | 없음 | `family` Stub 메모리만 | **NEW** |
| `household_request_items` | 위와 동일 | 없음 | `family` Stub 메모리만(응답 모델에만 존재) | **NEW** |
| `daily_reports` | 아내/남편 PDF W-REPORT-001/H-REPORT-001 서술과 일치(단, 남편 PDF의 H-REPORT-001은 문서 내부 모순 있음 — `BACKEND_STATUS.md` TBD 참고) | 없음 | `care` Stub 메모리만 | **NEW** |
| `notifications` | 남편 PDF H-NOTI-001 서술과 일치 | 없음 | `family` Stub 메모리만 | **NEW** |
| `motion_consents` | 아내/남편 PDF B-MOTION-001 ON/OFF 서술과 일치 | 없음 | `family` Stub 메모리만, WS 게이트(Protected) 미연동 | **NEW** |
| `chat_messages` | 아내 PDF W-CHAT-001 서술과 일치 | 없음 | Router/Service 자체가 없음 | **NEW** |
| `recommendation_feedback` | 아내 PDF W-MEAL-002/W-CHAT-001/W-SLEEP-001 이력 서술과 일치 | 없음 | Router/Service 자체가 없음 | **NEW** |
| `motion_sessions` | 아내/남편 PDF에 세션 개념 서술 없음(구 ERD 초안(삭제됨)이 "확인 필요한 가정"으로 자체 제안) | 없음 | `movement.py`가 프로세스 메모리(`SessionManager`, `_current_session_id`)로 대체 중(**Protected**) | **NOT_REQUIRED**(이번 MVP) |
| 캘린더, 임신 주수, 컨디션 4단계 지수, (실시간형) 오전 리포트 | 각 화면 PDF에 표시값으로만 서술, 저장 언급 없음 | 해당 없음 | 해당 없음(조회 시 계산) | **DERIVED** |

**5개 지정 테이블 확인 결과**: `pregnancy_profiles`, `daily_conditions`, `daily_routines`, `routine_items`, `pregnancy_knowledge` 모두 실제 migration에 존재하고 실제 코드가 사용 중이다. 구 ERD 초안(삭제됨)이 제안한 구조와 비교해도 컬럼 구성이 대부분 일치하며(`routine_items.source_ids`만 초안 표에 누락된 문서 오차), 5개 전부 **KEEP**이다 — 재생성·재설계 대상이 아니다.

---

## 분류 범례

- **KEEP**: 기존 migration 그대로 유지, 변경 없음.
- **EXTEND**: 기존 테이블에 컬럼 추가가 필요(신규 migration, 기존 migration 파일은 수정하지 않음). 이번 MVP에는 해당 사례 없음 — 5개 핵심 테이블 모두 이미 필요한 컬럼을 갖추고 있었다.
- **NEW**: 신규 테이블. migration 계획만 문서화, 아직 생성하지 않음.
- **NOT_REQUIRED**: 화면/문서가 언급하거나 구 ERD 초안(삭제됨)이 제안했지만 이번 MVP 범위에서는 테이블이 필요 없음(대체 수단으로 충분하거나 범위 밖).
- **DERIVED**: 테이블 없이 조회 시 계산.

---

## KEEP — 기존 테이블 (7개, 변경 없음)

### `pregnancy_profiles`

- **목적**: 임신 프로필 1~6단계(출산예정일·신체정보·초산경산·단태쌍태·알레르기·주의진단)의 유일한 SOURCE
- **PK**: `user_id`
- **FK**: `user_id → auth.users(id)` on delete cascade
- **Nullable/Unique/Index**: `due_date`만 not null(1단계 완료 전제), 나머지 단계 컬럼은 미완료 시 null 허용. 인덱스 없음(PK 조회만).
- **RLS**: 활성화, 정책 없음(service role만 접근)
- **Actor access**: Wife(본인 행 CRUD), Husband 접근 없음(원본 비노출, NFR-013)
- **관련 Screen**: W-PROFILE-001~007, W-HOME-001, W-MEAL-002, W-MENU-001
- **관련 FUC**: FUC-W-PROFILE-001~009
- **현재 존재 여부**: 존재(3개 migration 누적 적용)

| Column | Type | Nullable |
|---|---|---|
| user_id | uuid | NOT NULL (PK) |
| due_date | date | NOT NULL |
| last_period_start | date | NULL |
| height_cm | numeric(4,1) | NULL (check 100~250) |
| pre_pregnancy_weight_kg | numeric(4,1) | NULL (check 30~200) |
| is_first_pregnancy | boolean | NULL |
| is_multiple_pregnancy | boolean | NULL |
| allergies | text[] | NOT NULL default '{}' |
| medical_conditions | text[] | NOT NULL default '{}' |
| medical_note | text | NULL |
| created_at | timestamptz | NOT NULL default now() |
| updated_at | timestamptz | NOT NULL default now() |

### `daily_conditions`

- **목적**: 사용자·날짜당 1행의 당일 컨디션 7종 + 예정 활동 SOURCE
- **PK**: `(user_id, date)`
- **FK**: `user_id → auth.users(id)` cascade
- **Unique/Index**: PK 자체가 unique(user_id, date). 별도 인덱스 없음(현재는 PK 조회로 충분)
- **RLS**: 활성화, 정책 없음
- **Actor access**: Wife 전용(원본 비노출, NFR-013). 남편에게는 파생 지수만.
- **관련 Screen**: W-COND-001, W-TASK-001, W-HOME-001, B-CAL-001(파생)
- **관련 FUC**: FUC-W-COND-001~004, FUC-W-TASK-001
- **현재 존재 여부**: 존재(`20260917000001`)

| Column | Type | Nullable |
|---|---|---|
| user_id | uuid | NOT NULL (PK) |
| date | date | NOT NULL (PK) |
| nausea / waist_pain / pelvis_pain / leg_pain / wrist_pain / fatigue / mood | smallint | NOT NULL (check 1~5) |
| sleep_quality | smallint | NULL (check 1~5, 척도 미확정) |
| planned_activities | text[] | NOT NULL default '{}' |
| created_at / updated_at | timestamptz | NOT NULL default now() |

### `daily_routines` (Routine AI 소유)

- **목적**: 하루 루틴 생성 원본(AI/폴백) SOURCE, `user_id`+`date`당 1행 덮어쓰기
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade
- **Unique**: `unique(user_id, date)`
- **RLS**: 활성화, 정책 없음
- **Actor access**: Wife 전용
- **관련 Screen**: W-HOME-001, W-CALLBACK-001
- **관련 FUC**: FUC-W-ROUTINE-001/003
- **현재 존재 여부**: 존재(`20260917000001`). **Routine AI 소유.** 버전별 행 누적(revision·confirmed_at·change_summary)으로 변경 예정 — 웬즈데이 S3.

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| user_id | uuid | NOT NULL |
| date | date | NOT NULL |
| source | text | NOT NULL (check: ai/fallback_prev/fallback_template) |
| model / prompt_version | text | NULL |
| request_payload / response | jsonb | NULL |
| error_message | text | NULL |
| generated_at | timestamptz | NOT NULL default now() |

### `routine_items` (Routine AI 소유)

- **목적**: 카테고리별(meal/household/health/sleep) 루틴 항목 SOURCE — Meal/Household/Health/Sleep/Record 5개 화면 도메인의 공통 원본
- **PK**: `id`
- **FK**: `routine_id → daily_routines(id)` cascade, `user_id → auth.users(id)` cascade
- **Index**: `(user_id, date)`
- **RLS**: 활성화, 정책 없음
- **Actor access**: Wife(전체), Husband(가사 항목 완료 상태만 간접 갱신 — `household_request_items` FK 경유)
- **관련 Screen**: W-MEAL-001/002, W-HOUSE-001, W-HEALTH-001, W-SLEEP-001, W-RECORD-001/002
- **관련 FUC**: FUC-W-RECORD-001/002, FUC-W-HEALTH-002 등
- **현재 존재 여부**: 존재(`20260917000001`). **Routine AI 소유.** `change_kind` 컬럼 추가 예정 — 웬즈데이 S3.

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| routine_id | uuid | NOT NULL |
| user_id | uuid | NOT NULL |
| date | date | NOT NULL |
| category | text | NOT NULL (check: meal/household/health/sleep) |
| item_key | text | NOT NULL |
| title | text | NOT NULL |
| description | text | NULL |
| payload | jsonb | NOT NULL default '{}' |
| source_ids | bigint[] | NOT NULL default '{}' |
| status | text | NOT NULL default 'scheduled' (check: scheduled/completed/skipped) |
| completed_by | text | NULL (check: wife/husband/appliance) |
| completed_at | timestamptz | NULL |
| sort_order | smallint | NOT NULL default 0 |

### `pregnancy_knowledge` (Routine AI 소유)

- **목적**: RAG 지식 코퍼스(임베딩 검색용). 사용자 데이터 아님, 화면에 직접 노출되지 않음.
- **PK**: `id`(bigint)
- **FK**: 없음
- **Index**: `(week_start, week_end)`, `(category)`, hnsw on `embedding`
- **RLS**: 활성화, 정책 없음
- **Actor access**: 없음(Backend AI 파이프라인 전용 읽기)
- **관련 Screen**: 없음(간접 — 루틴 응답의 `source_ids`로만 연결)
- **관련 FUC**: FUC-W-ROUTINE-001(RAG 근거)
- **현재 존재 여부**: 존재(`20260917000000`, pgvector). **Routine AI 소유.**

### `posture_calibration_profiles` (Protected)

- **목적**: 개인 자세 기준선(baseline). 재캘리브레이션 여러 번 가능, 최신 1행이 현재 기준선.
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade
- **Index**: 없음(현재는 최신 1행 전체 스캔 — 필요 시 `(user_id, captured_at desc)` 고려 가능하나 이번 문서에서는 변경 제안 없음)
- **RLS**: 활성화, 정책 없음
- **Actor access**: Wife 전용
- **관련 Screen**: B-MOTION-001(캘리브레이션 단계)
- **관련 FUC**: FUC-B-MOTION-001
- **현재 존재 여부**: 존재(`20260916000000_create_movement_tables`). **Protected.** 구 ERD 초안(삭제됨)의 명칭(`posture_calibrations`)과 실제 테이블명이 달랐던 점은 초안 삭제로 해소됨(`DB_SCHEMA_RECONCILIATION.md` 기록됨).

### `posture_events` (Protected)

- **목적**: 부담 라벨이 Normal을 넘어선 임계 이벤트만 저장("위험한 순간만 저장" 원칙)
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade. `session_id`는 FK 제약 없이 `uuid not null`(참조 대상 `motion_sessions`가 없어 제약을 걸 수 없는 상태 — NOT_REQUIRED 결정과 일관)
- **Index**: `(user_id, started_at)`
- **RLS**: 활성화, 정책 없음
- **Actor access**: Wife(전체), Husband(조회 전용, 화면설계서 명시)
- **관련 Screen**: B-MOTION-001(아내/남편), W-REPORT-002
- **관련 FUC**: FUC-B-MOTION-001
- **현재 존재 여부**: 존재(`20260916000000_create_movement_tables`). **Protected.**

---

## NEW — 신규 테이블 계획 (10개, migration 미생성)

### `profiles`

- **목적**: 사용자 역할(wife/husband)과 표시 이름의 SOURCE — 현재 `account` Stub의 role 판정을 대체
- **PK**: `user_id`
- **FK**: `user_id → auth.users(id)` cascade
- **Nullable/Unique**: `role` NOT NULL, 나머지 NULL 허용
- **Index**: 없음(PK 조회로 충분)
- **RLS 필요 여부**: 필요(활성화, service role만 접근 — 기존 컨벤션과 동일)
- **Actor access**: Both(본인 행), 상대방 `display_name`은 `partner_links` 경유 조회
- **관련 Screen**: B-ENTRY-001, W-MENU-001, H-NOTI-001(발신자 표시)
- **관련 FUC**: FUC-B-ENTRY-001
- **현재 존재 여부**: 없음

| Column | Type | Nullable |
|---|---|---|
| user_id | uuid | NOT NULL (PK) |
| role | text | NOT NULL (check: wife/husband) |
| display_name | text | NULL |
| created_at | timestamptz | NOT NULL default now() |

### `partner_invitations`

- **목적**: 남편 초대 1회성 토큰 SOURCE
- **PK**: `id`
- **FK**: `wife_user_id → auth.users(id)` cascade
- **Unique**: `token`
- **Index**: `(wife_user_id)` 권장(초대 이력 조회용)
- **RLS 필요 여부**: 필요
- **Actor access**: Wife(생성), Husband(토큰 검증은 service role 경유, 직접 조회 없음)
- **관련 Screen**: W-INVITE-001, B-ENTRY-001(남편)
- **관련 FUC**: FUC-W-INVITE-001, FUC-H-INVITE-001(화면 자체는 TBD)
- **현재 존재 여부**: 없음
- **Notes**: NFR-026(72시간·1회성)은 `expires_at`+`used_at`으로 충족

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| wife_user_id | uuid | NOT NULL |
| token | text | NOT NULL (unique) |
| expires_at | timestamptz | NOT NULL |
| used_at | timestamptz | NULL |
| created_at | timestamptz | NOT NULL default now() |

### `partner_links`

- **목적**: 아내-남편 연동 상태 SOURCE — 모든 남편 공유 화면의 권한 판정 기준
- **PK**: `wife_user_id`
- **FK**: `wife_user_id`, `husband_user_id → auth.users(id)` cascade
- **Unique**: `husband_user_id`(중복 연동 방지)
- **Index**: 없음(양쪽 PK/unique로 조회 충분)
- **RLS 필요 여부**: 필요
- **Actor access**: Both(자신이 관련된 행만)
- **관련 Screen**: B-ENTRY-001, W-MENU-001, W-INVITE-001, B-CAL-001, B-MOTION-001, H-REPORT-001, H-NOTI-001, H-REQUEST-001 — 남편 공유 전체의 권한 기준
- **관련 FUC**: FUC-W-INVITE-001, FUC-H-INVITE-001, FUC-B-CAL-001 등 다수
- **현재 존재 여부**: 없음

| Column | Type | Nullable |
|---|---|---|
| wife_user_id | uuid | NOT NULL (PK) |
| husband_user_id | uuid | NOT NULL (unique) |
| linked_at | timestamptz | NOT NULL default now() |

### `household_requests`

- **목적**: 가사 도움 요청(이유·상태 전이) SOURCE — 아내가 쓰고 남편이 상태를 갱신하는 양방향 공유 테이블
- **PK**: `id`
- **FK**: `wife_user_id`, `husband_user_id → auth.users(id)` cascade
- **Index**: `(husband_user_id, status)`, `(wife_user_id, date)`
- **RLS 필요 여부**: 필요
- **Actor access**: Wife(생성/조회), Husband(조회/confirm/complete)
- **관련 Screen**: W-HOUSE-001, H-REQUEST-001, H-REQUEST-002, B-CAL-001(파생)
- **관련 FUC**: FUC-W-HOUSE-003, FUC-H-REQUEST-001~003
- **현재 존재 여부**: 없음

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| wife_user_id / husband_user_id | uuid | NOT NULL |
| date | date | NOT NULL |
| reason_text | text | NULL |
| status | text | NOT NULL default 'requested' (check: requested/confirmed/done) |
| requested_at | timestamptz | NOT NULL default now() |
| confirmed_at / done_at | timestamptz | NULL |

### `household_request_items`

- **목적**: 요청 카드 내 개별 집안일 항목 SOURCE — `routine_items` 원본을 FK로 재사용해 항목 내용 복제를 피한다
- **PK**: `id`
- **FK**: `request_id → household_requests(id)` cascade, `routine_item_id → routine_items(id)`(완료 동기화용, nullable)
- **Index**: `(request_id)` 권장
- **RLS 필요 여부**: 필요
- **Actor access**: 부모 `household_requests` 권한 상속
- **관련 Screen**: W-HOUSE-001, H-REQUEST-001
- **관련 FUC**: FUC-W-HOUSE-003, FUC-H-REQUEST-001
- **현재 존재 여부**: 없음
- **Notes**: `routine_item_id` FK 재사용 필수 — 항목 제목·설명을 여기 다시 저장하면 `DATA_OWNERSHIP.md`의 중복 저장 회피 원칙 위반

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| request_id | uuid | NOT NULL |
| routine_item_id | uuid | NULL |
| title | text | NOT NULL |
| helper_info | text | NULL |

### `daily_reports`

- **목적**: 확정된 Daily 리포트(및 필요 시 오전 리포트) 집계 SOURCE — 날짜당 1개(NFR-028)
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade(아내)
- **Unique**: `(user_id, date, kind)`
- **Index**: `(user_id, date)` 권장
- **RLS 필요 여부**: 필요
- **Actor access**: Wife(생성/확정), Husband(허용 범위만 조회, `shared_at` 이후)
- **관련 Screen**: W-REPORT-001, H-REPORT-001, B-CAL-001(파생)
- **관련 FUC**: FUC-W-REPORT-001/001-1/002, FUC-H-REPORT-001
- **현재 존재 여부**: 없음
- **Notes**: `kind` check는 `(morning, daily)` 둘 다 예약하되, 이번 MVP는 `daily`(W-REPORT-001 확정 흐름)만 실제로 채운다 — `morning`은 FUC-W-COND-002 자동 트리거가 문서상 "미반영"이라 오전 리포트는 우선 DERIVED(실시간 조회)로 처리하고, 트리거가 정식 구현되는 시점에 `kind=morning` 행 저장으로 전환한다.

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| user_id | uuid | NOT NULL |
| date | date | NOT NULL |
| kind | text | NOT NULL (check: morning/daily) |
| content | jsonb | NOT NULL |
| shared_at | timestamptz | NULL |
| created_at | timestamptz | NOT NULL default now() |

### `notifications`

- **목적**: 남편 알림(오전리포트/가사요청/컨디션변경) EVENT 로그
- **PK**: `id`
- **FK**: `recipient_user_id → auth.users(id)` cascade
- **Index**: `(recipient_user_id, read_at)`
- **RLS 필요 여부**: 필요
- **Actor access**: Husband(수신자 본인 행만)
- **관련 Screen**: H-NOTI-001
- **관련 FUC**: FUC-H-NOTI-001/002
- **현재 존재 여부**: 없음
- **Notes**: `type` 값은 구 ERD 초안(삭제됨)(4종: morning_report/household_request/daily_report/meal_share)이 아니라 **실제 `app/domains/family/schemas.py`의 `NotificationType`(3종: morning_report/household_request/condition_changed)을 기준으로 좁혔다** — 코드가 더 최신 계약이므로 문서보다 코드를 우선했다.

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| recipient_user_id | uuid | NOT NULL |
| type | text | NOT NULL (check: morning_report/household_request/condition_changed) |
| ref_id | uuid | NULL |
| title / body | text | NOT NULL |
| read_at | timestamptz | NULL |
| created_at | timestamptz | NOT NULL default now() |

### `motion_consents`

- **목적**: 모션 모니터링 동의·수집 ON/OFF SOURCE
- **PK**: `user_id`
- **FK**: `user_id → auth.users(id)` cascade
- **Index**: 없음(PK 조회로 충분)
- **RLS 필요 여부**: 필요
- **Actor access**: Wife 전용(남편은 조회도 불가, 화면설계서 명시)
- **관련 Screen**: B-MOTION-001
- **관련 FUC**: FUC-B-MOTION-001, NFR-012
- **현재 존재 여부**: 없음
- **Notes**: 테이블 신설과 `WS /movement/live/stream`(Protected) 연결 게이트 연동은 별개 작업 — 이 문서는 스키마만 정의하며, 실제 게이트 연동은 `DOMAIN_OWNERSHIP.md`가 이미 "보호된 movement.py 변경 필요, 별도 합의 후 진행"으로 명시한 TBD를 그대로 따른다.

| Column | Type | Nullable |
|---|---|---|
| user_id | uuid | NOT NULL (PK) |
| enabled | boolean | NOT NULL default false |
| updated_at | timestamptz | NOT NULL default now() |

### `chat_messages`

- **목적**: 챗봇 대화 이력 SOURCE(MVP는 식사 가이드 재조정 한정)
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade, `routine_item_id → routine_items(id)`(nullable)
- **Index**: `(user_id, date, created_at)`
- **RLS 필요 여부**: 필요
- **Actor access**: Wife 전용(NFR-013, 남편 비노출)
- **관련 Screen**: W-CHAT-001
- **관련 FUC**: FUC-W-CHAT-001/002, FUC-W-MEAL-003
- **현재 존재 여부**: 없음
- **Notes**: NFR-027(보관·파기 기준 TBD, 원문은 Daily 리포트에 미반영)이 아직 결정되지 않아, 실제 migration 작성 전 보관 기간 정책을 먼저 확정해야 한다(TBD 유지, 이 문서는 컬럼 구조만 제시)

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| user_id | uuid | NOT NULL |
| date | date | NOT NULL |
| routine_item_id | uuid | NULL |
| role | text | NOT NULL (check: user/assistant) |
| content | text | NOT NULL |
| suggested_actions | jsonb | NULL |
| created_at | timestamptz | NOT NULL default now() |

### `recommendation_feedback`

- **목적**: 메뉴 수락/거절/재요청, 수면 환경 override 이력 SOURCE(도메인별 별도 테이블 대신 `kind`로 통합)
- **PK**: `id`
- **FK**: `user_id → auth.users(id)` cascade, `routine_item_id → routine_items(id)` cascade
- **Index**: `(user_id, created_at desc)`
- **RLS 필요 여부**: 필요
- **Actor access**: Wife 전용
- **관련 Screen**: W-MEAL-002, W-CHAT-001, W-SLEEP-001(팝업)
- **관련 FUC**: FUC-W-MEAL-004, FUC-W-SLEEP-001-1
- **현재 존재 여부**: 없음
- **Notes**: `docs/requirements/04_1_기능요구사항명세서.md` 기준 FUC-W-MEAL-004 우선순위 중 — MVP 후순위지만 `routine_items`와 독립적이라 스키마 자체는 이번 Target Schema에 포함해 둔다.

| Column | Type | Nullable |
|---|---|---|
| id | uuid | NOT NULL (PK) |
| user_id | uuid | NOT NULL |
| routine_item_id | uuid | NOT NULL |
| kind | text | NOT NULL (check: meal_accept/meal_reject/meal_replace/sleep_env_override) |
| payload | jsonb | NULL |
| created_at | timestamptz | NOT NULL default now() |

---

## NOT_REQUIRED — 이번 MVP에서 만들지 않는 테이블

### `motion_sessions`

- **목적(제안됐던 것)**: 진행 중인 모션 세션 상태(현재 자세, 누적 시간)를 DB로 영속화
- **현재 대체 수단**: `app/services/movement/session_manager.py`의 `SessionManager` + 전역 변수 `_current_session_id`(프로세스 메모리)
- **NOT_REQUIRED 판단 근거**: (1) 구 ERD 초안(삭제됨)이 자체적으로 "확인 필요한 가정"으로 표시해 팀 확정값이 아님. (2) 도입하려면 Protected `movement.py`의 `/live` 조회 로직을 메모리 기반에서 DB 기반으로 바꿔야 하는데, 이는 "Routine/AI 구조를 깨기 위해 테이블을 재설계하지 않는다"는 이번 STEP의 원칙과 같은 이유로 Protected 모듈에 대한 별도 합의 없이는 손대지 않는다. (3) 현재 데모 범위(단일 세션 가정)에서는 메모리로 충분히 동작 중(`DOMAIN_OWNERSHIP.md`도 "별도 합의 후 진행"으로 이미 보류).
- **재검토 시점**: 다중 사용자 실서비스 전환, 서버 재시작 내성이 요구사항으로 확정될 때. 그때도 `posture_events.session_id`에 FK를 새로 거는 등 기존 Protected 테이블 변경이 필요하므로 별도 논의를 먼저 거친다.

---

## DERIVED — 테이블 없이 조회 시 계산

| 데이터 | 계산 근거 | 관련 Screen |
|---|---|---|
| 임신 주수·일수 | `pregnancy_profiles.due_date - 280일` 기준 | W-HOME-001, H-REPORT-001, W-MENU-001 |
| 컨디션 4단계 지수(좋음/보통/나쁨/힘듦) | `daily_conditions` 점수 기준(계산식 TBD) | B-CAL-001 |
| 캘린더 월간 조회 | `daily_conditions`+`routine_items`+`daily_reports` 조회 조합 | B-CAL-001 |
| 오전 리포트(자동 트리거 구현 전) | `daily_conditions`+`routine_items` 실시간 파생 | H-REPORT-001 |

---

## 다음 단계(문서 범위 밖)

이 문서는 계획만 제시한다. 실제 migration 작성 전 확정해야 할 선행 결정:

1. `chat_messages` 보관·파기 기준(NFR-027, TBD)
2. `motion_consents` ↔ `WS /movement/live/stream` 연동 방식(Protected 모듈 합의 필요)
3. `daily_reports.kind='morning'` 자동 생성 트리거 구현 여부(FUC-W-COND-002, 현재 "미반영")
4. `notifications.type` 값 확정(현재 코드 3종 vs 구 ERD 초안(삭제됨) 4종 — 코드 기준으로 좁혔으나 팀 재확인 필요)

이 4가지가 정리되면 신규 테이블 10개를 기능 우선순위(`docs/requirements/04_1_기능요구사항명세서.md` 상/중/하)에 맞춰 여러 개의 신규 migration으로 나눠 작성한다.
