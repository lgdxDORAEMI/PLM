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
- Notes: 화면설계서 PDF가 서술하는 생년월일/나이 필드는 Request/Response에 없다 — `pregnancy_profiles`에 컬럼이 없고 `DB_ERD_스키마.md`가 이미 FR 범위 밖으로 제외

### `PUT /api/v1/profile/me/pregnancy-history` [planned]

- Actor: Wife
- Screen: W-PROFILE-003, W-PROFILE-004
- FUC: FUC-W-PROFILE-003, FUC-W-PROFILE-004
- Use Case: UC1
- Request: `PregnancyHistoryInput { is_first_pregnancy: bool, is_multiple_pregnancy: bool }`(두 화면이 같은 리소스를 부분 갱신 — due-date/body와 같은 PATCH형 관례)
- Response: `ProfileResponse`(due-date/body와 동일 DTO에 두 필드 추가)
- Source Data: `pregnancy_profiles.is_first_pregnancy/is_multiple_pregnancy`
- Authorization: 기본값
- Error: 409(1단계 미완료), 422(둘 다 없음)
- Status: **planned**

### `PUT /api/v1/profile/me/allergies` [planned]

- Actor: Wife
- Screen: W-PROFILE-005
- FUC: FUC-W-PROFILE-005
- Use Case: UC1
- Request: `AllergiesInput { allergies: string[] }`("없어요" 선택 시 빈 배열)
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles.allergies`
- Authorization: 기본값
- Error: 409(선행 단계 미완료)
- Status: **planned**

### `PUT /api/v1/profile/me/medical-notes` [planned]

- Actor: Wife
- Screen: W-PROFILE-006
- FUC: FUC-W-PROFILE-006
- Use Case: UC1
- Request: `MedicalNotesInput { medical_conditions: string[], medical_note?: string }`
- Response: `ProfileResponse`
- Source Data: `pregnancy_profiles.medical_conditions/medical_note`
- Authorization: 기본값
- Error: 409(선행 단계 미완료)
- Status: **planned**

---

## Account (진입/연동/초대)

### `GET /api/v1/account/bootstrap`

- Actor: Both
- Screen: B-ENTRY-001
- FUC: FUC-B-ENTRY-001
- Use Case: UC17
- Request: 없음
- Response: `BootstrapResponse { role, profile: missing|incomplete|complete|null, partner_link: unlinked|linked, destination }`
- Source Data: `profiles`(MISSING) + `pregnancy_profiles` + `partner_links`(MISSING)
- Authorization: 기본값
- Error: 없음(항상 200)
- Status: **stub** — 역할 판정 로직이 항상 Wife 고정(`DOMAIN_OWNERSHIP.md` 기존 TBD)

### `GET /api/v1/account/partner-link`

- Actor: Wife
- Screen: W-MENU-001, W-INVITE-001(연동 여부 확인)
- FUC: FUC-W-MENU-001
- Use Case: UC1(연계)
- Request: 없음
- Response: `PartnerLinkResponse { status: unlinked|linked, partner_display_name? }`
- Source Data: `partner_links`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **stub**

### `POST /api/v1/account/partner-invitations`

- Actor: Wife
- Screen: W-INVITE-001
- FUC: FUC-W-INVITE-001
- Use Case: UC15
- Request: 없음
- Response: `InvitationResponse { invitation_id, invitation_url, expires_at }`
- Source Data: `partner_invitations`(MISSING)
- Authorization: 기본값
- Error: 없음(현재 Stub 기준)
- Status: **stub** — NFR-026(72시간·1회성) 제약은 실 구현 시 반드시 적용

### `POST /api/v1/account/partner-invitations/{token}/accept` [planned]

- Actor: Husband
- Screen: B-ENTRY-001(남편, 초대 수락 경로)
- FUC: FUC-H-INVITE-001
- Use Case: UC16
- Request: 경로 파라미터 `token`만(본문 없음, 인증은 계정 생성/로그인 이후 호출 전제)
- Response: `PartnerLinkResponse { status: linked, partner_display_name }`
- Source Data: `partner_invitations`(검증) → `partner_links`(신규 행 생성)
- Authorization: 기본값(남편 계정으로 로그인된 상태)
- Error: 404(토큰 없음), 410(만료/이미 사용됨), 409(이미 다른 아내와 연동됨)
- Status: **planned** — 화면·인증 복귀 계약 자체가 `DOMAIN_OWNERSHIP.md`에서 TBD

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
- Status: **stub** — **계약 결함 있음**: `birth_date`가 필수 필드인데 `pregnancy_profiles`에 대응 컬럼이 없다. 실제 Supabase adapter로 교체하기 전에 `PUT /profile/me/due-date`·`/body`·`/pregnancy-history`·`/allergies`·`/medical-notes` 5개 단계별 API로 흡수 통합하거나, `birth_date` 요구 자체를 제거해야 한다(`DATA_OWNERSHIP.md` Duplicate Storage 항목 8 참고)

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
- Error: 404(해당 날짜 기록 없음)
- Status: **stub** — DB `daily_conditions`는 존재하지만 이 API는 메모리만 사용, 실제 테이블 미연결

### `PUT /api/v1/care/conditions/{target_date}`

- Actor: Wife
- Screen: W-COND-001
- FUC: FUC-W-COND-001
- Use Case: UC2
- Request: `ConditionInput { nausea, waist_pain, pelvis_pain, leg_pain, wrist_pain, fatigue, mood: 1~5 }`
- Response: `ConditionResponse`(위와 동일, `write_kind`로 created/updated/new_routine_required 구분)
- Source Data: `daily_conditions`
- Authorization: 기본값
- Error: 없음(현재 Stub 기준)
- Status: **stub**

### `PUT /api/v1/care/conditions/{target_date}/activities`

- Actor: Wife
- Screen: W-TASK-001
- FUC: FUC-W-TASK-001
- Use Case: UC3
- Request: `PlannedActivitiesInput { activities: string[] }`(9종 코드+직접입력, 최대 20개)
- Response: `ConditionResponse`
- Source Data: `daily_conditions.planned_activities`
- Authorization: 기본값
- Error: 422(80자 초과 항목)
- Status: **stub**

### `PUT /api/v1/care/routine-items/{item_id}/execution`

- Actor: Wife
- Screen: W-HEALTH-001(완료체크), W-MEAL-001/002, W-SLEEP-001(공통 완료 컴포넌트)
- FUC: FUC-W-RECORD-001, FUC-W-HEALTH-002
- Use Case: UC6
- Request: `RoutineExecutionInput { status: scheduled|completed|skipped|needs_confirmation }`
- Response: `RoutineExecutionResponse { routine_item_id, category, title, status, completed_by?, completed_at? }`
- Source Data: `routine_items.status/completed_by/completed_at`(별도 실행 로그 테이블 아님 — `DATA_OWNERSHIP.md` Duplicate Storage 항목 3)
- Authorization: 기본값
- Error: 없음(현재 Stub 기준)
- Status: **stub**

### `PUT /api/v1/care/routine-items/{item_id}` [planned]

- Actor: Wife
- Screen: W-CHAT-001("이걸로 할게요" 대체 메뉴 수락)
- FUC: FUC-W-MEAL-003, FUC-W-MEAL-004
- Use Case: UC4
- Request: `RoutineItemUpdateInput { payload: MealPayload, feedback_kind: meal_accept|meal_reject|meal_replace }`
- Response: `RoutineItemResponse { routine_item_id, category, title, payload }`(갱신된 항목)
- Source Data: `routine_items.payload`(갱신) + `recommendation_feedback`(이력 기록, MISSING)
- Authorization: 기본값
- Error: 404(항목 없음), 409(오늘 루틴 아님)
- Status: **planned**

### `PUT /api/v1/care/routine-items/{item_id}/sleep-environment` [planned]

- Actor: Wife
- Screen: W-SLEEP-001(바텀시트 팝업)
- FUC: FUC-W-SLEEP-001-1
- Use Case: UC11, UC12
- Request: `SleepEnvironmentInput { lighting?, temperature?, humidity?, sound?, air_purifier? }`(AI 권장값 대비 override)
- Response: `RoutineItemResponse`(sleep payload 갱신본)
- Source Data: `routine_items.payload`(sleep) + `recommendation_feedback`(kind=sleep_env_override, MISSING)
- Authorization: 기본값
- Error: 404, 422(범위 초과: 온도 0~40, 습도 0~100)
- Status: **planned**

### `POST /api/v1/care/daily-reports/{target_date}/preview`

- Actor: Wife
- Screen: W-HOME-001("오늘의 일정 마치기"), W-REPORT-001(미리보기)
- FUC: FUC-W-HOME-002, FUC-W-REPORT-001
- Use Case: UC7
- Request: 없음
- Response: `DailyReportResponse { report_id, target_date, finalized: false, completed_routines, appliance_executions, routines[], highest_load_area?, motion_cautions[], family{requested,confirmed,completed}, updated_at }`
- Source Data: `daily_conditions`+`routine_items`+`posture_events`(조회 조합, 미저장)
- Authorization: 기본값
- Error: 없음(현재 Stub 기준)
- Status: **stub**

### `POST /api/v1/care/daily-reports/{target_date}/finalize`

- Actor: Wife
- Screen: W-REPORT-001("저장하고 마치기")
- FUC: FUC-W-REPORT-001, FUC-W-REPORT-001-1
- Use Case: UC7
- Request: 없음
- Response: `DailyReportResponse`(`finalized: true`)
- Source Data: `daily_reports`(MISSING, 확정 시 1행 생성/`kind=daily`)
- Authorization: 기본값
- Error: 없음(현재 Stub 기준). 실 구현 시 NFR-028(날짜당 1개) 위반은 409
- Status: **stub**

### `GET /api/v1/care/daily-reports/{target_date}`

- Actor: Wife, Husband(허용 범위만 별도 API로 조회, 아래 `morning-reports` 참고)
- Screen: W-REPORT-001(과거 조회), B-CAL-001(상세 진입)
- FUC: FUC-W-REPORT-001/002
- Use Case: UC7
- Request: 경로 `target_date`
- Response: `DailyReportResponse`
- Source Data: `daily_reports`(MISSING)
- Authorization: 기본값
- Error: 404(해당 날짜 리포트 없음)
- Status: **stub**

### `GET /api/v1/care/calendar/{month}`

- Actor: Wife, Husband(읽기 전용)
- Screen: B-CAL-001
- FUC: FUC-B-CAL-001
- Use Case: UC7, UC10
- Request: 경로 `month`(YYYY-MM)
- Response: `CalendarMonthResponse { month, days: [{ target_date, condition_index: good|fair|bad|hard, has_report, report_finalized }] }`
- Source Data: `daily_conditions`+`routine_items`+`daily_reports`(조회 조합, VIEW)
- Authorization: 기본값
- Error: 422(month 형식 오류)
- Status: **stub** — 남편 role별 응답 필터링(수정 권한 제거)은 미구현

---

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
- Status: **stub**

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
- Status: **stub**

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
- Status: **stub**

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
- Status: **stub**

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
- Status: **stub**

---

## Report (남편 공유)

### `GET /api/v1/family/morning-reports/{target_date}`

- Actor: Husband
- Screen: H-REPORT-001
- FUC: FUC-H-REPORT-001
- Use Case: UC8
- Request: 경로 `target_date`
- Response: `MorningReportResponse { target_date, pregnancy_week, condition_summary[], planned_activities[], guide_summaries: {meal, household, health, sleep} }`(프로필 원본·컨디션 원본·AI 대화 원문 미포함, NFR-013)
- Source Data: `daily_conditions`+`routine_items`(허용 범위만 파생) 또는 `daily_reports`(kind=morning, MISSING)
- Authorization: 기본값(연동된 남편만)
- Error: 403(미연동), 404(해당 날짜 리포트 없음)
- Status: **stub** — 남편 PDF의 H-REPORT-001 두 버전이 가이드 요약 포함 여부를 다르게 서술(`BACKEND_STATUS.md` TBD), `guide_summaries` 포함 여부는 재확인 필요

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
- Status: **stub**

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
- Status: **stub**

---

## Chat

### `GET /api/v1/chat/messages` [planned]

- Actor: Wife
- Screen: W-CHAT-001
- FUC: FUC-W-CHAT-001
- Use Case: UC4
- Request: 쿼리 `date`(기본 오늘)
- Response: `ChatMessageResponse[] { message_id, role: user|assistant, content, suggested_actions?, created_at }`
- Source Data: `chat_messages`(MISSING)
- Authorization: 기본값
- Error: 없음(빈 배열 허용)
- Status: **planned**

### `POST /api/v1/chat/messages` [planned]

- Actor: Wife
- Screen: W-CHAT-001
- FUC: FUC-W-CHAT-001
- Use Case: UC4, UC11
- Request: `ChatMessageInput { content: string, routine_item_id?: string }`
- Response: `ChatMessageResponse`(AI 응답 메시지, `suggested_actions`에 루틴 변경 제안 포함 가능)
- Source Data: `chat_messages`(MISSING) 저장 + `routine_items`/`pregnancy_profiles`/`daily_conditions` 읽기(AI 컨텍스트, NFR-014 최소 항목)
- Authorization: 기본값
- Error: 422(빈 입력), 503(AI 서비스 오류)
- Status: **planned** — NFR-027(대화 이력 보관·파기 기준 TBD) 확정 후 구현

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
- Error: 1008(origin 불허/토큰 무효)
- Status: **implemented**

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
- Status: **implemented** — 남편 조회 시 부부 연동 검증(권한 분기)은 미구현

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
- Status: **implemented**

### `GET /api/v1/family/motion/privacy`

- Actor: Wife
- Screen: B-MOTION-001
- FUC: FUC-B-MOTION-001, NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse { consent_granted, collection_enabled, updated_at }`
- Source Data: `motion_consents`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **stub**

### `PUT /api/v1/family/motion/consent`

- Actor: Wife
- Screen: B-MOTION-001(최초 동의)
- FUC: NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse`(`consent_granted: true`)
- Source Data: `motion_consents`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **stub**

### `DELETE /api/v1/family/motion/consent`

- Actor: Wife
- Screen: B-MOTION-001(동의 철회)
- FUC: NFR-012
- Use Case: UC13
- Request: 없음
- Response: `MotionPrivacyResponse`(`consent_granted: false, collection_enabled: false`)
- Source Data: `motion_consents`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **stub** — `WS /movement/live/stream`(Protected) 연결 게이트와 미연동, 별도 합의 필요

### `PUT /api/v1/family/motion/collection`

- Actor: Wife
- Screen: B-MOTION-001(ON/OFF 토글)
- FUC: FUC-B-MOTION-001
- Use Case: UC13
- Request: `MotionCollectionInput { enabled: bool }`
- Response: `MotionPrivacyResponse`
- Source Data: `motion_consents.enabled`(MISSING)
- Authorization: 기본값
- Error: 없음
- Status: **stub** — OFF는 신규 감지만 중단, 기존 기록은 삭제하지 않음(`DOMAIN_OWNERSHIP.md` 원칙)

---

## 요약

전체 42개 API(기존 34 + 신규 제안 8) 중 **implemented 9 / stub 25 / planned 8**. **partial은 0개** — 실 저장소에 연결됐지만 범위가 어긋난 사례(`PUT/GET /account/profile`의 `birth_date` 불일치)는 Stub 자체이므로 partial이 아니라 stub으로 분류했다. 상세 수치와 화면별 매트릭스는 `API_IMPLEMENTATION_MATRIX.md` 참고.
