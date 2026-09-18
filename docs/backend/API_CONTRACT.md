# API Contract

- 작성일: 2026-09-17 (STEP 5)
- 기준: `docs/backend/SCREEN_DATA_API_MAPPING.md`(화면→API), `docs/backend/TARGET_DB_SCHEMA.md`(테이블 설계), 실제 `backend/app/api/v1/**`·`backend/app/domains/**/schemas.py`.
- 이 문서는 계약 정의이며 코드를 수정하지 않는다.
- 공통 Authorization: 모든 API는 `Authorization: Bearer <Supabase access token>`을 요구한다(`get_current_user` 검증). 이하 API별로는 이 기본값과 다를 때만 별도 표기한다.
- 공통 Error: 401(토큰 없음/무효), 503(Supabase 연결 실패)은 거의 모든 API에 공통이라 이하 API별로는 그 외의 상태 코드만 표기한다.

## 계층 경계 원칙과 현재 코드의 실제 상태

요청한 경계는 `DB Schema → Repository Model → Service DTO → API Response`이다. 실제 코드를 다시 확인한 결과:

- **`account`/`care`/`family` 3개 도메인은 이미 이 경계를 강제하는 구조다.** `domains/*/repository.py`의 Protocol이 반환 타입을 raw row가 아니라 `domains/*/schemas.py`의 Pydantic DTO(`ConditionResponse`, `HouseholdRequestResponse` 등)로 **직접 선언**한다. Router는 Service만, Service는 Repository Protocol만 알고, Protocol의 반환 타입 자체가 이미 API Response와 동일한 DTO다 — 즉 Stub을 Supabase adapter로 교체해도 **adapter 내부에서 DB row(dict) → 이 DTO로의 매핑만 새로 구현**하면 되고, Router·Service·API 계약은 전혀 바뀌지 않는다. 이번 STEP에서 이 구조를 재확인했고 변경할 필요가 없다고 판단했다.
- **`profile.py`/`profile_service.py`(실 구현)는 이 경계를 모범적으로 지킨다.** `_to_response(row: Row) -> ProfileResponse`가 raw Supabase row를 받아 `pregnancy_weeks`/`completed_step`처럼 DB에 없는 계산 필드까지 채워 DTO로 변환한다. DB 컬럼이 늘어나도 `ProfileResponse` 필드가 그대로면 Frontend는 영향받지 않는다.
- **`routine.py`(Protected, 실 구현)는 부분적으로만 지킨다.** `GET/POST /routine/today`는 `daily_routines` 행을 `.select("id, date, source, model, generated_at, response")`로 컬럼을 제한해 그대로 반환한다 — 별도 DTO 클래스를 두지 않고 select 컬럼 제한으로 최소 노출만 한다. `response` 컬럼 자체는 이미 카테고리별 구조화된 JSON(원본 테이블 컬럼이 아니라 애초에 DTO 형태로 설계된 jsonb)이라 원칙을 심각하게 위반하지는 않지만, 엄밀한 Repository Model 계층은 없다. **Protected 모듈이라 이 문서에서 구조 변경을 제안하지 않는다** — 현재 상태를 그대로 계약으로 기록한다.
- 아래 각 API의 "Source Data"는 `TARGET_DB_SCHEMA.md`의 Source Table을, "Response"는 실제/제안 DTO를 가리키며 절대 테이블명을 Path나 필드명으로 노출하지 않는다.

## 상태 정의

- **implemented**: Supabase에 실제로 연결되어 동작. 코드·테스트 확인됨.
- **partial**: 실 저장소에 연결돼 있으나 계약 일부가 요구사항과 불일치하거나 범위가 축소돼 있음.
- **stub**: 인메모리 Stub Repository로만 동작. 재시작 시 초기화, 실제 영속화 없음.
- **planned**: 코드 없음. 이 문서에서 신규 제안.

---

## Profile

### `GET /api/v1/profile/me`

- Actor: Wife
- Screen: W-PROFILE-001, W-PROFILE-007, W-HOME-001(간접), W-MENU-001
- FUC: FUC-W-PROFILE-001, FUC-W-PROFILE-007
- Use Case: UC1
- Request: 없음(경로/바디 없음)
- Response: `ProfileResponse { due_date, last_period_start, height_cm, pre_pregnancy_weight_kg, pregnancy_weeks, pregnancy_days, completed_step }`
- Source Data: `pregnancy_profiles`(1~2단계 컬럼만 select) → `_to_response()`가 `pregnancy_weeks`/`pregnancy_days`/`completed_step` 계산 필드 추가
- Authorization: 기본값
- Error: 404(등록된 프로필 없음)
- Status: **implemented**

### `PUT /api/v1/profile/me/due-date`

- Actor: Wife
- Screen: W-PROFILE-001
- FUC: FUC-W-PROFILE-001
- Use Case: UC1
- Request: `DueDateInput { due_date?: date, last_period_start?: date }`(둘 중 하나 필수)
- Response: `ProfileResponse`(위와 동일 구조)
- Source Data: `pregnancy_profiles`
- Authorization: 기본값
- Error: 422(둘 다 없음/범위 초과/미래 생리 시작일)
- Status: **implemented**

### `PUT /api/v1/profile/me/body`

- Actor: Wife
- Screen: W-PROFILE-002
- FUC: FUC-W-PROFILE-002
- Use Case: UC1
- Request: `BodyInput { height_cm: number(100~250), pre_pregnancy_weight_kg: number(30~200) }`
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles`
- Authorization: 기본값
- Error: 409(1단계 출산예정일 미저장), 422(범위 초과)
- Status: **implemented**
- Notes: 최신 FUC-W-PROFILE-002는 생년월일을 필수 입력으로 요구하지만 현재 Request/Response와 `pregnancy_profiles` 컬럼에는 없다. `birth_date` migration과 계약 확장이 필요하다.

### `PUT /api/v1/profile/me/pregnancy-history`

- Actor: Wife
- Screen: W-PROFILE-003
- FUC: FUC-W-PROFILE-003
- Use Case: UC1
- Request: `PregnancyHistoryInput { is_first_pregnancy: bool }`
- Response: `ProfileResponse`(due-date/body와 동일 DTO에 필드 추가)
- Source Data: `pregnancy_profiles.is_first_pregnancy`
- Authorization: 기본값
- Error: 409(1단계 미완료), 422
- Status: **implemented**
- Notes(STEP 8 구현 메모): 원래 STEP 5는 이 엔드포인트에 `is_multiple_pregnancy`까지 묶었으나, W-PROFILE-003/004가 실제로는 별개 화면(3/6, 4/6)이라 구현 시 `PUT /pregnancy-count`로 분리했다 — due-date/body처럼 화면 1개당 API 1개 원칙을 지켰다.

### `PUT /api/v1/profile/me/pregnancy-count`

- Actor: Wife
- Screen: W-PROFILE-004
- FUC: FUC-W-PROFILE-004
- Use Case: UC1
- Request: `PregnancyCountInput { is_multiple_pregnancy: bool }`
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles.is_multiple_pregnancy`
- Authorization: 기본값
- Error: 409(1단계 미완료), 422
- Status: **implemented**

### `PUT /api/v1/profile/me/allergies`

- Actor: Wife
- Screen: W-PROFILE-005
- FUC: FUC-W-PROFILE-005
- Use Case: UC1
- Request: `AllergiesInput { allergies: string[] }`("없어요" 선택 시 빈 배열)
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles.allergies`
- Authorization: 기본값
- Error: 409(1단계 미완료)
- Status: **implemented**
- Notes: `allergies`는 DB가 `not null default '{}'`라 "미입력"과 "빈 배열 선택"을 구분할 수 없어, 이 단계는 `completed_step` 계산에 포함하지 않는다(`ProfileResponse.completed_step`은 최대 4까지만 정확 — TBD, 스키마 변경 없이는 해결 안 됨).

### `PUT /api/v1/profile/me/medical-notes`

- Actor: Wife
- Screen: W-PROFILE-006
- FUC: FUC-W-PROFILE-006
- Use Case: UC1
- Request: `MedicalNotesInput { medical_conditions: string[], medical_note?: string }`
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles.medical_conditions/medical_note`
- Authorization: 기본값
- Error: 409(1단계 미완료)
- Status: **implemented**

---

## Account (진입/연동/초대)

### `GET /api/v1/account/bootstrap`

- Actor: Both
- Screen: B-ENTRY-001
- FUC: FUC-B-ENTRY-001
- Use Case: UC17
- Request: 없음
- Response: `BootstrapResponse { role, profile: missing|incomplete|complete|null, partner_link: unlinked|linked, destination }`
- Source Data: `profiles` + `pregnancy_profiles` + `partner_links`
- Authorization: 기본값
- Error: 없음(항상 200)
- Status: **implemented**(STEP 13) — `profiles` 행이 없으면 여전히 Wife로 기본 처리한다(`DOMAIN_OWNERSHIP.md` 기존 TBD와 동일 결정, 새로 바꾸지 않음). 남편은 초대 수락 시점에 `profiles` 행이 생겨 이 기본값을 거치지 않는다.

### `GET /api/v1/account/partner-link`

- Actor: Wife
- Screen: W-MENU-001, W-INVITE-001(연동 여부 확인)
- FUC: FUC-W-MENU-001
- Use Case: UC1(연계)
- Request: 없음
- Response: `PartnerLinkResponse { status: unlinked|linked, partner_display_name? }`
- Source Data: `partner_links`
- Authorization: 기본값
- Error: 없음
- Status: **implemented**(STEP 13) — `partner_display_name`은 상대방 `profiles.display_name`을 읽지만 아무 화면도 이 값을 아직 채우지 않아 대개 `null`이다(지어내지 않음)

### `POST /api/v1/account/partner-invitations`

- Actor: Wife
- Screen: W-INVITE-001
- FUC: FUC-W-INVITE-001
- Use Case: UC15
- Request: 없음
- Response: `InvitationResponse { invitation_id, invitation_url, expires_at }`
- Source Data: `partner_invitations`
- Authorization: 기본값
- Error: 409(프로필 미완료 또는 이미 연동됨)
- Status: **implemented**(STEP 13) — NFR-026(72시간)은 `partner_invitations_max_72h` DB CHECK 제약(STEP 7)으로 강제, 1회성은 `used_at` 컬럼으로 강제

### `POST /api/v1/account/partner-invitations/{token}/accept`

- Actor: Husband
- Screen: B-ENTRY-001(남편, 초대 수락 경로)
- FUC: FUC-H-INVITE-001
- Use Case: UC16
- Request: 경로 파라미터 `token`만(본문 없음, 인증은 계정 생성/로그인 이후 호출 전제)
- Response: `PartnerLinkResponse { status: linked, partner_display_name }`
- Source Data: `partner_invitations`(검증) → `partner_links`(신규 행 생성, 복제 없음)
- Authorization: 기본값(남편 계정으로 로그인된 상태)
- Error: 404(토큰 없음), 409(만료/이미 사용됨/이미 다른 아내와 연동됨)
- Status: **implemented**(STEP 13) — 화면·인증 복귀 계약 자체는 여전히 `DOMAIN_OWNERSHIP.md`에서 TBD(이 API의 존재 자체는 유효). 연동 시도(`link_partner`)를 토큰 소비보다 먼저 수행하도록 순서를 바로잡았다(STEP 13에서 발견한 버그 수정 — 실패해도 토큰이 먼저 소진되지 않음). 남편 표시 이름은 지어내지 않고 `null`로 둔다.

### `GET/PUT /api/v1/account/profile`

- Actor: Wife
- Screen: W-PROFILE-007(요약), W-PROFILE-008(수정)
- FUC: FUC-W-PROFILE-007, FUC-W-PROFILE-008
- Use Case: UC1
- Request(PUT): `ProfileInput { due_date?, last_period_start?, birth_date, height_cm, pre_pregnancy_weight_kg, is_first_pregnancy, is_multiple_pregnancy, allergies[], medical_conditions[], medical_note }`
- Response: `ProfileResponse { ProfileInput 필드 전체 + pregnancy_weeks, age, completed, updated_at }`
- Source Data: `pregnancy_profiles`(의도상 전체), 단 `birth_date`/`age`는 DB 컬럼 없음
- Authorization: 기본값
- Error: 없음(현재 Stub 기준)
- Status: **stub** — **계약 결함 있음**: 최신 FUC에서 필수인 `birth_date`의 `pregnancy_profiles` 대응 컬럼이 없다. 실제 Supabase adapter로 교체하기 전에 migration을 추가하고 `PUT /profile/me/body`를 포함한 단계별 API 계약에 흡수 통합해야 한다(`DATA_OWNERSHIP.md` Duplicate Storage 항목 8 참고).

---

## Routine (Protected)

### `GET /api/v1/routine/today`

- Actor: Wife
- Screen: W-HOME-001, W-MEAL-001, W-MEAL-002, W-HOUSE-001, W-HEALTH-001, W-SLEEP-001
- FUC: FUC-W-HOME-001, FUC-W-MEAL-001/002, FUC-W-HOUSE-001, FUC-W-HEALTH-001, FUC-W-SLEEP-001
- Use Case: UC3, UC11
- Request: 없음
- Response: `{ id, date, source: ai|fallback_prev|fallback_template, model, generated_at, response: { meal: Item[], household: Item[], health: Item[], sleep: Item } }`(`Item = { item_key, title, payload, source_ids }`, 카테고리별 payload 모양은 `TARGET_DB_SCHEMA.md`의 `routine_items` 참고)
- Source Data: `daily_routines` + `routine_items`(카테고리별) — Frontend는 `response.{category}`만 읽고 `routine_items` 테이블명을 알 필요가 없다
- Authorization: 기본값
- Error: 404(오늘 루틴 없음)
- Status: **implemented**

### `POST /api/v1/routine/today`

- Actor: Wife
- Screen: W-TASK-001("AI 하루루틴 만들기"), W-CALLBACK-001("다시 시도하기")
- FUC: FUC-W-ROUTINE-001, FUC-W-CALLBACK-001, FUC-W-ROUTINE-003(폴백)
- Use Case: UC3, UC11
- Request: 없음(서버가 저장된 프로필·오늘 컨디션을 조회해 생성)
- Response: `GET /routine/today`와 동일 DTO
- Source Data: `pregnancy_profiles`+`daily_conditions`(입력) → `daily_routines`+`routine_items`(저장)
- Authorization: 기본값
- Error: 409(프로필 1단계 또는 오늘 컨디션 미입력)
- Status: **implemented** — AI 실호출 1회 검증은 OpenAI 크레딧 대기(폴백 경로는 실DB 검증 완료)

---

## Condition / Care

### `GET /api/v1/care/conditions/{target_date}`

- Actor: Wife
- Screen: W-COND-001
- FUC: FUC-W-COND-001
- Use Case: UC2
- Request: 경로 `target_date`
- Response: `ConditionResponse { nausea, waist_pain, pelvis_pain, leg_pain, wrist_pain, fatigue, mood, target_date, planned_activities[], changed_fields[], write_kind, updated_at }`
- Source Data: `daily_conditions`
- Authorization: 기본값
- Error: 404(해당 날짜 기록 없음), 503(Supabase 연결 실패)
- Status: **implemented**(STEP 9) — 조회는 아무것도 바꾸지 않으므로 `changed_fields`는 항상 `[]`, `write_kind`는 조회 맥락에서 의미가 없어 중립값 `updated`를 고정 반환한다(지어내지 않음)

### `PUT /api/v1/care/conditions/{target_date}`

- Actor: Wife
- Screen: W-COND-001
- FUC: FUC-W-COND-001
- Use Case: UC2
- Request: `ConditionInput { nausea, waist_pain, pelvis_pain, leg_pain, wrist_pain, fatigue, mood: 1~5 }`
- Response: `ConditionResponse`(위와 동일)
- Source Data: `daily_conditions`
- Authorization: 기본값
- Error: 422(범위 초과), 503
- Status: **implemented**(STEP 9) — `write_kind`는 `created`/`updated`만 정확히 구분한다. FUC-W-COND-004의 `new_routine_required`(확정된 Daily 리포트가 있을 때)는 `daily_reports`가 아직 실 연동되지 않아(Report 도메인은 별도 STEP) 이번 구현에서 판단하지 않는다 — TBD로 남긴다.

### `PUT /api/v1/care/conditions/{target_date}/activities`

- Actor: Wife
- Screen: W-TASK-001
- FUC: FUC-W-TASK-001
- Use Case: UC3
- Request: `PlannedActivitiesInput { activities: string[] }`(9종 코드+직접입력, 최대 20개, 중복 제거)
- Response: `ConditionResponse`
- Source Data: `daily_conditions.planned_activities`
- Authorization: 기본값
- Error: 409(해당 날짜 컨디션 미저장), 503
- Status: **implemented**(STEP 9)

### `PUT /api/v1/care/routine-items/{item_id}/execution`

- Actor: Wife
- Screen: W-HEALTH-001(완료체크), W-MEAL-001/002, W-SLEEP-001(공통 완료 컴포넌트)
- FUC: FUC-W-RECORD-001, FUC-W-HEALTH-002
- Use Case: UC6
- Request: `RoutineExecutionInput { status: scheduled|completed|skipped|needs_confirmation }`
- Response: `RoutineExecutionResponse { routine_item_id, category, title, status, completed_by?, completed_at? }`
- Source Data: `routine_items.status/completed_by/completed_at`(별도 실행 로그 테이블 아님 — `DATA_OWNERSHIP.md` Duplicate Storage 항목 3)
- Authorization: 기본값
- Error: 404(항목 없음/다른 사용자 소유), 409(`needs_confirmation`은 DB CHECK 제약상 아직 저장 불가)
- Status: **implemented**(STEP 12)

### `PUT /api/v1/care/routine-items/{item_id}`

- Actor: Wife
- Screen: W-CHAT-001("이걸로 할게요" 대체 메뉴 수락)
- FUC: FUC-W-MEAL-003, FUC-W-MEAL-004
- Use Case: UC4
- Request: `RoutineItemUpdateInput { payload: object, feedback_kind: meal_accept|meal_reject|meal_replace }`
- Response: `RoutineItemResponse { routine_item_id, category, title, payload }`(갱신된 항목)
- Source Data: `routine_items.payload`(갱신) + `recommendation_feedback`(이력 기록, MISSING)
- Authorization: 기본값
- Error: 422(요청 형식)
- Status: **stub** — 실제 `routine_items`(Protected) 원본을 모르므로 `title`은 항상 `null`, `category`는 고정값 `meal`, `payload`는 요청을 그대로 반영한다(지어내지 않음). `recommendation_feedback` 테이블이 없어 이력은 저장하지 않는다.

### `PUT /api/v1/care/routine-items/{item_id}/sleep-environment`

- Actor: Wife
- Screen: W-SLEEP-001(바텀시트 팝업)
- FUC: FUC-W-SLEEP-001-1
- Use Case: UC11, UC12
- Request: `SleepEnvironmentInput { lighting?, temperature?, humidity?, sound?, air_purifier? }`(AI 권장값 대비 override)
- Response: `RoutineItemResponse`(sleep payload 갱신본)
- Source Data: `routine_items.payload`(sleep) + `recommendation_feedback`(kind=sleep_env_override, MISSING)
- Authorization: 기본값
- Error: 422(범위 초과: 온도 0~40, 습도 0~100)
- Status: **stub** — 위와 동일한 이유로 `category=sleep` 고정, `payload`는 요청에서 값이 온 필드만 반영

### `POST /api/v1/care/daily-reports/{target_date}/preview`

- Actor: Wife
- Screen: W-HOME-001("오늘의 일정 마치기"), W-REPORT-001(미리보기)
- FUC: FUC-W-HOME-002, FUC-W-REPORT-001
- Use Case: UC7
- Request: 없음
- Response: `DailyReportResponse { report_id, target_date, finalized: false, completed_routines, appliance_executions, routines[], highest_load_area?, motion_cautions[], family{requested,confirmed,completed}, updated_at }`
- Source Data: `daily_conditions`(존재 확인)+`routine_items`(Record)+`posture_events`(Movement, `generate_daily_report()` 재사용)에서 매번 계산만 한다 — `daily_reports`에는 쓰지 않는다(NFR-028)
- Authorization: 기본값
- Error: 404(해당 날짜 컨디션 없음)
- Status: **implemented**(STEP 12) — `family`는 Household 도메인이 아직 실 연결 전이라 항상 `{0,0,0}`(지어내지 않음, TBD)

### `POST /api/v1/care/daily-reports/{target_date}/finalize`

- Actor: Wife
- Screen: W-REPORT-001("저장하고 마치기")
- FUC: FUC-W-REPORT-001, FUC-W-REPORT-001-1
- Use Case: UC7
- Request: 없음
- Response: `DailyReportResponse`(`finalized: true`)
- Source Data: `daily_reports`(확정 시 1행 upsert, `kind=daily`, `unique(user_id,date,kind)`로 NFR-028 보장 — 같은 날짜 재확정은 덮어쓰기, 중복 생성 아님)
- Authorization: 기본값
- Error: 404(해당 날짜 컨디션 없음)
- Status: **implemented**(STEP 12)

### `GET /api/v1/care/daily-reports/{target_date}`

- Actor: Wife, Husband(허용 범위만 별도 API로 조회, 아래 `morning-reports` 참고)
- Screen: W-REPORT-001(과거 조회), B-CAL-001(상세 진입)
- FUC: FUC-W-REPORT-001/002
- Use Case: UC7
- Request: 경로 `target_date`
- Response: `DailyReportResponse`
- Source Data: `daily_reports`
- Authorization: 기본값
- Error: 404(해당 날짜 리포트 없음 — 확정 전이면 항상 404, 미리보기는 저장되지 않으므로)
- Status: **implemented**(STEP 12)

### `GET /api/v1/care/calendar/{month}`

- Actor: Wife, Husband(읽기 전용)
- Screen: B-CAL-001
- FUC: FUC-B-CAL-001
- Use Case: UC7, UC10
- Request: 경로 `month`(YYYY-MM)
- Response: `CalendarMonthResponse { month, days: [{ target_date, condition_index: good|fair|bad|hard, has_report, report_finalized }] }`
- Source Data: `daily_conditions`+`daily_reports`(조회 조합, VIEW — 별도 저장 테이블 없음)
- Authorization: 기본값
- Error: 422(month 형식 오류)
- Status: **implemented**(STEP 12) — `condition_index` 계산식은 04_3 개발순서 #2 기준 문서상 미확정이라 임시 규칙(통증·피로 6종 평균 4구간)을 쓴다(`condition_index_from_scores()`). 남편 role별 응답 필터링(수정 권한 제거)은 여전히 미구현

---

## Guide Query — Meal / Household / Health / Sleep (STEP 11)

`routine_items`(Protected 테이블)를 읽기 전용으로 조회하는 Query Layer다. Routine AI를 카테고리별로 다시 호출하지 않으며, `daily_routines.response`(생성 시점 스냅샷)가 아니라 `routine_items` 원본에서 읽어 실행 상태(완료 체크)가 항상 최신으로 반영된다. 4개 API 모두 계약이 동일해 한 번에 기술한다.

### `GET /api/v1/meals/today` · `GET /api/v1/household/today` · `GET /api/v1/health/today` · `GET /api/v1/sleep/today`

- Actor: Wife
- Screen: `meals`→W-MEAL-001/002, `household`→W-HOUSE-001, `health`→W-HEALTH-001, `sleep`→W-SLEEP-001
- FUC: FUC-W-MEAL-001/002, FUC-W-HOUSE-001, FUC-W-HEALTH-001, FUC-W-SLEEP-001
- Use Case: UC3, UC11
- Request: 쿼리 `date`(기본 오늘, KST)
- Response: `GuideResponse { date, category: meal|household|health|sleep, items: [{ item_key, title, description?, payload: object, status: scheduled|completed|skipped, completed_by?: wife|husband|appliance, completed_at? }] }`
- Source Data: `daily_routines`(존재 확인용) + `routine_items`(category 필터, `sort_order` 정렬)
- Authorization: 기본값
- Error: 404(오늘 생성된 루틴 자체가 없음 — `GET /routine/today`와 동일 조건). 해당 카테고리에 항목이 0개인 것은 오류가 아니라 `items: []`로 정상 응답한다.
- Status: **implemented**
- Notes: `app/domains/guide/query_service.py`가 유일한 구현이며 `app/services/routine/**`/`app/api/v1/routine.py`(Protected)는 이 API를 구현하며 전혀 수정하지 않았다.

## Household

### `POST /api/v1/family/household-requests`

- Actor: Wife
- Screen: W-HOUSE-001("남편에게 공유하기")
- FUC: FUC-W-HOUSE-003
- Use Case: UC5
- Request: `HouseholdRequestCreate { target_date, reason, items: [{ title, helper_info?, routine_item_id? }] }`(1~20개)
- Response: `HouseholdRequestResponse { request_id, target_date, requester_display_name, recipient_display_name, reason, status: unconfirmed, items[{item_id,title,helper_info?,routine_item_id?,status}], requested_at }`
- Source Data: `household_requests`+`household_request_items`(MISSING, `routine_item_id`로 `routine_items` FK 재사용)
- Authorization: 기본값
- Error: 409(파트너 미연동)
- Status: **implemented** — `household_requests` 실 연결(STEP 17). 남편 연동(`partner_links`) 없으면 409, 생성 시 남편에게 `household_request` 알림 1건 발송

### `GET /api/v1/family/household-requests`

- Actor: Wife, Husband
- Screen: W-HOUSE-001(진행상태), H-REQUEST-001(목록)
- FUC: FUC-W-RECORD-002, FUC-H-REQUEST-001
- Use Case: UC6, UC9
- Request: 없음(본인 기준 필터)
- Response: `HouseholdRequestResponse[]`
- Source Data: `household_requests`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **implemented** — `household_requests`를 wife/husband 양쪽 user_id로 조회(STEP 17)

### `GET /api/v1/family/household-requests/{request_id}`

- Actor: Husband
- Screen: H-REQUEST-001
- FUC: FUC-H-REQUEST-001
- Use Case: UC9
- Request: 경로 `request_id`
- Response: `HouseholdRequestResponse`
- Source Data: `household_requests`+`household_request_items`(MISSING)
- Authorization: 기본값(요청·수신 당사자만)
- Error: 403(권한 없는 부부 조합), 404
- Status: **implemented** — 요청 소유 부부가 아니면 403(STEP 17)

### `POST /api/v1/family/household-requests/{request_id}/confirm`

- Actor: Husband
- Screen: H-REQUEST-001("확인")
- FUC: FUC-H-REQUEST-002
- Use Case: UC9
- Request: 없음
- Response: `HouseholdRequestResponse`(`status: confirmed`)
- Source Data: `household_requests.status`(MISSING)
- Authorization: 기본값(수신 남편만)
- Error: 403, 409(이미 확인/완료됨)
- Status: **implemented** — 수신 남편만 가능, 이미 completed면 409. `household_requests.status/confirmed_at`과 각 `household_request_items.status` 갱신(STEP 17)

### `POST /api/v1/family/household-requests/{request_id}/complete`

- Actor: Husband
- Screen: H-REQUEST-001("완료했어요"+확인팝업)
- FUC: FUC-H-REQUEST-002, FUC-H-REQUEST-003
- Use Case: UC9
- Request: 없음
- Response: `HouseholdRequestResponse`(`status: completed`)
- Source Data: `household_requests.status`(MISSING) + `routine_items.status/completed_by=husband`(동기화)
- Authorization: 기본값(수신 남편만)
- Error: 403, 409(미확인 상태에서 완료 시도)
- Status: **implemented** — confirmed 상태에서만 가능, 그 외 409. 상태 변화 자체는 새 알림을 만들지 않는다(FUC-H-NOTI-001 제약, STEP 17)

---

## Report (남편 공유)

### `GET /api/v1/family/morning-reports/{target_date}`

- Actor: Husband
- Screen: H-REPORT-001
- FUC: FUC-H-REPORT-001
- Use Case: UC8
- Request: 경로 `target_date`
- Response: `MorningReportResponse { target_date, pregnancy_week, condition_summary[], planned_activities[], guide_summaries: {category: title 나열} }`(프로필 원본·컨디션 원본·AI 대화 원문 미포함, NFR-013)
- Source Data: `partner_links`(family authorization) → `pregnancy_profiles`+`daily_conditions`+`routine_items`(그 자리에서 읽는 projection, 복사 저장 없음)
- Authorization: 기본값(연동된 남편만 — `partner_links.husband_user_id`로 확인)
- Error: 403(연동된 아내 계정 없음), 404(해당 날짜 컨디션 없음)
- Status: **implemented**(STEP 12) — `condition_summary`는 원본 1~5 점수를 그대로 노출하지 않고 "높음"만 정성 문구로 뽑는다(임계값도 TBD, 04_3 #2와 같은 성격). 남편 PDF의 H-REPORT-001 두 버전이 가이드 요약 포함 여부를 다르게 서술한 점은(`BACKEND_STATUS.md` TBD) `guide_summaries`를 포함하는 쪽으로 확정 구현했다.

---

## Notification

### `GET /api/v1/family/notifications`

- Actor: Husband
- Screen: H-NOTI-001
- FUC: FUC-H-NOTI-001
- Use Case: UC8, UC9, UC14
- Request: 없음
- Response: `NotificationResponse[] { notification_id, type: morning_report|household_request|condition_changed, title, body, target_date?, reference_id, created_at, read_at? }`
- Source Data: `notifications`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **implemented** — `notifications`를 `recipient_user_id`로 조회, `created_at` 내림차순(STEP 17). 발송 트리거 3종: 가사 요청 생성(`household_request`), 하루 첫 루틴 생성(`morning_report`), 루틴 재생성(`condition_changed`) — 뒤 둘은 `POST /routine/today` 성공 직후 발송(FUC-W-COND-002/003)

### `POST /api/v1/family/notifications/{notification_id}/read`

- Actor: Husband
- Screen: H-NOTI-001
- FUC: FUC-H-NOTI-001
- Use Case: UC14
- Request: 없음
- Response: `NotificationResponse`(`read_at` 채워짐)
- Source Data: `notifications.read_at`(MISSING)
- Authorization: 기본값
- Error: 404
- Status: **implemented** — `id`+`recipient_user_id`로 갱신, 남의 알림이면 404(STEP 17)

---

## Chat

### `GET /api/v1/chat/messages`

- Actor: Wife
- Screen: W-CHAT-001
- FUC: FUC-W-CHAT-001
- Use Case: UC4
- Request: 쿼리 `date`(기본 오늘)
- Response: `ChatMessageResponse[] { message_id, role: user|assistant, content, suggested_actions?, created_at }`
- Source Data: `chat_messages`(MISSING, 현재는 프로세스 메모리)
- Authorization: 기본값
- Error: 없음(빈 배열 허용)
- Status: **stub**

### `POST /api/v1/chat/messages`

- Actor: Wife
- Screen: W-CHAT-001
- FUC: FUC-W-CHAT-001
- Use Case: UC4, UC11
- Request: `ChatMessageInput { content: string, routine_item_id?: string }`
- Response: `ChatMessageResponse`(AI 응답 메시지)
- Source Data: `chat_messages`(MISSING) 저장 + `routine_items`/`pregnancy_profiles`/`daily_conditions` 읽기(AI 컨텍스트, NFR-014 최소 항목)
- Authorization: 기본값
- Error: 422(빈 입력)
- Status: **stub** — NFR-027(대화 이력 보관·파기 기준 TBD) 확정 전이라 실제 AI를 호출하지 않고 고정 안내 문구("아직 실제 AI 응답 기능은 준비 중이에요")만 반환한다 — 실제 조언·메뉴를 지어내지 않는다.

---

## Movement (Protected)

### `WS /api/v1/movement/live/stream`

- Actor: Wife
- Screen: B-MOTION-001(캘리브레이션+실시간 판정)
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: 쿼리 `token`(access token), 바이너리 JPEG 프레임 스트림
- Response: `{"type":"calibration_progress"|"calibration_done"}` 또는 `{"type":"frame","data":PostureFrameState}`(WebSocket 메시지, 프레임/landmark는 응답에만 존재하고 저장하지 않음 — NFR-011)
- Source Data: `posture_calibration_profiles`(캘리브레이션 저장) + `posture_events`(임계 이벤트만 저장)
- Authorization: 쿼리 파라미터 `token`(WebSocket은 헤더 미지원이라 예외)
- Error: 1008(origin 불허/토큰 무효), **4003**(동의 없음 또는 수집 OFF — `motion_consents`, STEP 18), 1011(동의 조회 실패)
- Status: **implemented** — STEP 18에서 연결 시점 동의 게이트 추가(NFR-012). 스트림 도중 철회는 프론트가 WS를 끊는다

### `GET /api/v1/movement/live`

- Actor: Wife
- Screen: B-MOTION-001(실시간 탭)
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: 없음
- Response: `LiveAccumulatedState`(현재 자세·누적 부담 시간 등, 세션 없으면 404)
- Source Data: 프로세스 메모리(`SessionManager`, `motion_sessions` 미도입 — `TARGET_DB_SCHEMA.md` NOT_REQUIRED 결정)
- Authorization: 기본값
- Error: 404(활성 세션 없음)
- Status: **implemented** — 데모 단일 세션 한정(다중 사용자 미지원, README 명시)

### `GET /api/v1/movement/events`

- Actor: Wife, Husband(조회 전용)
- Screen: B-MOTION-001
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: 없음
- Response: `PostureEvent[] { event_id, posture_type, burden_label, trigger_reason, started_at, ended_at, duration_sec }`
- Source Data: `posture_events`
- Authorization: 기본값
- Error: 없음
- Status: **implemented** — STEP 18: 남편은 `partner_links`로 연동된 아내 데이터를 읽기 전용 조회(`api/v1/partner_scope.py`, 캘린더와 공용). 미연동 사용자는 본인(빈) 데이터

### `GET /api/v1/movement/report/daily`

- Actor: Wife, Husband(조회 전용)
- Screen: B-MOTION-001, W-REPORT-002
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: 쿼리 `date`(기본 오늘)
- Response: `DailyReportSummary { aggregates[], top_burdened_body_part?, bending_burden_event_count }`
- Source Data: `posture_events`(집계)
- Authorization: 기본값
- Error: 없음
- Status: **implemented** — STEP 18: 남편은 연동된 아내의 리포트(`partner_scope`)

### `GET /api/v1/family/motion/privacy`

- Actor: Wife
- Screen: B-MOTION-001
- FUC: FUC-B-MOTION-001, NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse { consent_granted, collection_enabled, updated_at }`
- Source Data: `motion_consents`
- Authorization: 기본값
- Error: 없음(행이 없으면 미동의 기본값 반환, 지어내지 않음)
- Status: **implemented**(STEP 14)

### `PUT /api/v1/family/motion/consent`

- Actor: Wife
- Screen: B-MOTION-001(최초 동의)
- FUC: NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse`(`consent_granted: true`)
- Source Data: `motion_consents`
- Authorization: 기본값
- Error: 없음
- Status: **implemented**(STEP 14)

### `DELETE /api/v1/family/motion/consent`

- Actor: Wife
- Screen: B-MOTION-001(동의 철회)
- FUC: NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse`(`consent_granted: false, collection_enabled: false`)
- Source Data: `motion_consents`
- Authorization: 기본값
- Error: 없음
- Status: **implemented** — STEP 18에서 `WS /movement/live/stream` 연결 게이트와 연동: 철회 이후 새 연결은 4003으로 거부된다

### `PUT /api/v1/family/motion/collection`

- Actor: Wife
- Screen: B-MOTION-001(ON/OFF 토글)
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: `MotionCollectionInput { enabled: bool }`
- Response: `MotionPrivacyResponse`
- Source Data: `motion_consents.collection_enabled`
- Authorization: 기본값
- Error: 409(동의 없이 켜려는 시도)
- Status: **implemented**(STEP 14) — OFF는 신규 감지만 중단, 기존 기록은 삭제하지 않음(`DOMAIN_OWNERSHIP.md` 원칙, DB 컬럼도 분리돼 있어 자연히 지켜짐)

---

## 요약

- 작성일: 2026-09-17 (STEP 5 초안, STEP 8에서 8개 planned API 구현, STEP 9·STEP 10·STEP 11·STEP 17(2026-09-18)에서 갱신)
- STEP 9: `GET/PUT /care/conditions/{date}`, `PUT /care/conditions/{date}/activities`가 실제 `daily_conditions`에 연결됐다. `app/services/routine/inputs.py`(Protected)가 같은 테이블·같은 컬럼명을 읽으므로 호환성을 확인하는 통합 테스트를 추가했다(`tests/test_care_condition.py`). Care 도메인의 나머지 메서드(execution/report/routine-item 피드백/캘린더)는 여전히 Stub — 같은 Repository 안에서 fallback으로 위임한다.
- STEP 10: 프로필 1~6단계 필드를 화면설계서·DB와 재대조해 신규 컬럼/migration이 필요 없음을 확정하고, 회귀·남편 비공개 테스트를 추가했다(코드 변경 없음, `tests/test_profile.py`만 확장).
- STEP 11: `GET /api/v1/meals/today`·`/household/today`·`/health/today`·`/sleep/today` 4개를 신규 구현했다(`app/domains/guide/**`, `app/api/v1/guide.py`) — `routine_items`를 읽기 전용으로 조회하는 Query Layer이며 새 테이블도, AI 재호출도 없다. 전체 API가 43개 → **47개**가 됐다.
- STEP 12: Record(`PUT .../routine-items/{id}/execution`), Report(`POST .../preview`·`.../finalize`, `GET .../daily-reports/{date}`), Calendar(`GET .../calendar/{month}`), 남편 오전 리포트(`GET /family/morning-reports/{date}`) 6개를 stub→implemented로 전환했다. 새 테이블은 만들지 않았다 — Record는 `routine_items` 컬럼을 직접 갱신, Report는 Record+Condition+Movement에서 매번 계산, Calendar는 조회 조합, 남편 리포트는 `partner_links` 기반 projection이다.
- STEP 17: Household 5개·Notification 2개를 stub→implemented로 전환했다(`household_requests`/`household_request_items`/`notifications` 실 연결, `app/domains/family/supabase_repository.py`). 같은 STEP에서 (1) `GET /care/calendar/{month}`가 남편 호출 시 `partner_links`로 연동된 아내 캘린더를 읽기 전용 조회하도록 분기(계약 변경 없음), (2) Daily 리포트 `family` 집계를 `household_requests` 실조회(누적 funnel: requested=그날 전체, confirmed=confirmed 이상, completed=completed)로 교체, (3) `POST /routine/today` 성공 직후 남편 알림 발송(첫 생성 `morning_report`, 재생성 `condition_changed`; 남편 미연동 시 생략, 발송 실패해도 201 유지)을 연결했다 — 라우트 응답 계약은 모두 그대로다.
- STEP 8 구현 결과 W-PROFILE-003/004를 묶었던 `pregnancy-history` 1개가 화면 단위(due-date/body 관례)에 맞춰 `pregnancy-history`+`pregnancy-count` 2개로 나뉘어, 전체 API는 42개 → **43개**(기존 34 + 신규 9)가 됐다.
- 프로필 4개(`pregnancy-history`/`pregnancy-count`/`allergies`/`medical-notes`)는 `pregnancy_profiles` 컬럼이 이미 있어 **implemented**(Supabase 실연결)로 구현했다.
- 나머지 5개(`chat/messages` GET·POST, `care/routine-items/{id}` PUT, `.../sleep-environment` PUT, `account/partner-invitations/{token}/accept` POST)는 지원 테이블이 없거나(chat_messages, recommendation_feedback) 화면 계약 자체가 TBD(H-INVITE-001)라 **stub**(프로세스 메모리, 실제 데이터 지어내지 않음)으로 구현했다.
- STEP 8 종료 시점 집계: implemented 13 / stub 30 / planned 0. STEP 9에서 Condition 3개가 stub→implemented로 바뀌어 implemented 16 / stub 27(합계 43). STEP 11에서 Guide Query 4개가 신규 implemented로 추가돼 implemented 20 / stub 27(합계 47). STEP 12에서 Record/Report/Calendar/남편 오전 리포트 6개가 stub→implemented로 바뀌어 implemented 26 / stub 21(합계 47). STEP 13에서 파트너 연동 4개(bootstrap/partner-link/invitations 발급·수락)가 stub→implemented로 바뀌어 implemented 30 / stub 17(합계 47). STEP 14에서 모션 동의 4개(`family/motion/privacy`·`/consent`·`/collection`)가 stub→implemented로 바뀌어 implemented 34 / stub 13(합계 47). STEP 17에서 Household 5개·Notification 2개가 stub→implemented로 바뀌어 **최종 집계는 implemented 41 / stub 6 / planned 0**(합계 47). partial은 0개 — `PUT/GET /account/profile`의 `birth_date` 불일치는 여전히 남아 있지만 그 자체가 Stub이므로 partial이 아니라 stub으로 분류한다. 상세 수치와 화면별 매트릭스는 `API_IMPLEMENTATION_MATRIX.md` 참고.
