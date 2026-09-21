# Requirement Traceability (STEP 16 — 최종 검증, STEP 17 갱신)

- 작성일: 2026-09-18 (STEP 17에서 Household/Notification 실연결·남편 캘린더 분기·family 집계·루틴 생성 알림 반영)
- 기준 문서 7종(서비스 흐름도 제외):
  1. `docs/requirements/아내_화면설계서.pdf`
  2. `docs/requirements/남편_화면설계서.pdf`
  3. `docs/requirements/아내 화면 DB스키마.pdf`(실은 화면 필드 서술 — STEP 0에서 확인된 사실, 아래 §부가검증 참고)
  4. `docs/requirements/남편 화면 DB 스키마.pdf`(위와 동일)
  5. `docs/requirements/04_1_기능요구사항명세서.md`
  6. `docs/requirements/03_유스케이스명세서.md`
  7. `docs/requirements/04_2_비기능요구사항명세서.md`
- 이 문서는 STEP 0~15의 결과를 하나의 표로 통합한 최종 검증 문서다. 개별 근거는 `docs/backend/BACKEND_STATUS.md`, `DATA_OWNERSHIP.md`, `TARGET_DB_SCHEMA.md`, `API_CONTRACT.md`, `API_IMPLEMENTATION_MATRIX.md`, `SCREEN_DATA_API_MAPPING.md`, `DB_SCHEMA_RECONCILIATION.md`, `BACKEND_ARCHITECTURE.md`, `docs/frontend/API_INTEGRATION_STATUS.md`에 있다.
- 검증 시점 테스트 결과: **Backend 117개 전부 통과**(`backend/tests`, unittest), **Frontend 78개 중 77개 통과**(`flutter test`, 실패 1건은 `git stash`로 재현해 이번 작업과 무관한 기존 결함임을 확인 — STEP 15에서 이미 기록).

## Status 정의

- **PASS**: 화면이 요구하는 데이터가 실제 DB에 연결된 API로 서빙되고, 그 API를 검증하는 자동 테스트가 있다.
- **PARTIAL**: 화면의 일부 기능/데이터만 PASS 수준이고 나머지는 STUB이거나 값이 항상 0/빈 값으로 고정되는 등 알려진 제약이 있다.
- **STUB**: API 계약은 있으나 여전히 인메모리(Stub Repository)만 사용한다.
- **FRONT_ONLY**: 저장할 데이터가 없는 순수 Navigation/UI 상태라 Backend API가 필요 없다.
- **PHASE_2**: ThinQ 가전 제어 등 MVP 범위 밖으로 이미 확정된 기능이다.
- **TBD**: 화면 흐름·계약 자체가 요구사항 문서 안에서 미확정이거나 상충한다(코드 문제가 아니라 문서 확정이 먼저 필요).

---

## Trace Table — Wife

| Actor | Screen | FUC | Use Case | Data | DB | API | Test | Status |
|---|---|---|---|---|---|---|---|---|
| Wife | B-ENTRY-001 | FUC-B-ENTRY-001 | UC17 | role, 프로필 완료, 연동 상태 | `profiles`, `pregnancy_profiles`, `partner_links` | `GET /account/bootstrap` | `test_account_partner_link.py::RelationshipAuthorizationTest::test_bootstrap_destination_depends_on_partner_links_not_a_copy` | PASS |
| Wife | W-PROFILE-001 | FUC-W-PROFILE-001 | UC1 | 출산예정일, 마지막 생리 시작일 | `pregnancy_profiles` | `PUT /profile/me/due-date` | `test_profile.py::ProfileApiTest::test_step_by_step_save`, `DueDateInputTest` | PASS |
| Wife | W-PROFILE-002 | FUC-W-PROFILE-002 | UC1 | 생년월일→나이, 신장, 체중 | `pregnancy_profiles` | `PUT /profile/me/body` | `test_profile.py::BodyInputTest`, `test_step_by_step_save` | PARTIAL — 최신 FUC에 복구된 `birth_date` 컬럼·단계 API 미구현 |
| Wife | W-PROFILE-003 | FUC-W-PROFILE-003 | UC1 | 초산/경산 | `pregnancy_profiles.is_first_pregnancy` | `PUT /profile/me/pregnancy-history` | `test_profile.py::test_steps_3_to_6_require_step_1_first` | PASS |
| Wife | W-PROFILE-004 | FUC-W-PROFILE-004 | UC1 | 단태/쌍태 | `pregnancy_profiles.is_multiple_pregnancy` | `PUT /profile/me/pregnancy-count` | 동일 | PASS |
| Wife | W-PROFILE-005 | FUC-W-PROFILE-005 | UC1 | 알레르기 | `pregnancy_profiles.allergies` | `PUT /profile/me/allergies` | 동일 | PASS |
| Wife | W-PROFILE-006 | FUC-W-PROFILE-006 | UC1 | 주의진단, 메모 | `pregnancy_profiles.medical_conditions/medical_note` | `PUT /profile/me/medical-notes` | 동일 | PASS |
| Wife | W-PROFILE-007 | FUC-W-PROFILE-007/008 | UC1 | 1~6단계 요약 | `pregnancy_profiles` | `GET /profile/me` | `test_profile.py::test_full_six_step_completion_flow`, `test_husband_cannot_read_wifes_profile` | PASS |
| Wife | W-INVITE-001 | FUC-W-INVITE-001 | UC15 | 초대 토큰/URL/만료 | `partner_invitations` | `POST /account/partner-invitations` | `test_account_partner_link.py::test_issued_invitation_has_72h_expiry_and_is_unused` | PASS |
| Wife | W-HOME-001 | FUC-W-HOME-001/002 | UC2, UC3, UC7 | 인사말, 주차, 컨디션 요약, 루틴 4종, "일정 마치기" | `pregnancy_profiles`+`daily_conditions`+`daily_routines`/`routine_items` | `GET /routine/today` + `GET /care/conditions/{date}` + `POST /care/daily-reports/{date}/preview` | `test_routine_service.py`, `test_care_condition.py`, `test_care_report.py::ReportApiTest` | PASS — `family` 집계도 `household_requests` 실조회(STEP 17) |
| Wife | W-COND-001 | FUC-W-COND-001 | UC2 | 입덧/허리/골반/다리/손목/피로/기분 | `daily_conditions` | `GET/PUT /care/conditions/{date}` | `test_care_condition.py`(14개: create/read/update/validation/auth/isolation/KST 경계) | PASS |
| Wife | W-TASK-001 | FUC-W-TASK-001 | UC3 | 예정 활동 | `daily_conditions.planned_activities` | `PUT /care/conditions/{date}/activities` + `POST /routine/today` | `test_care_condition.py::test_save_activities_requires_condition_first`, `test_routine_service.py` | PASS |
| Wife | W-MEAL-001 | FUC-W-MEAL-001 | UC3, UC11 | 끼니별 요약 | `routine_items`(category=meal) | `GET /meals/today` | `test_guide_query.py` | PASS |
| Wife | W-MEAL-002 | FUC-W-MEAL-002 | UC3, UC11 | 메뉴/이유/영양태그 | `routine_items.payload` | `GET /meals/today` | 동일 | PASS |
| Wife | W-CHAT-001(재추천+공통, 병합) | FUC-W-MEAL-003, FUC-W-CHAT-001/002 | UC4, UC11 | 대화, 대체 메뉴 | `chat_messages`(MISSING, 인메모리) | `GET/POST /chat/messages` | `test_backend_skeleton.py::test_chat_message_round_trip_does_not_fabricate_ai_reply` | STUB |
| Wife | W-HOUSE-001 | FUC-W-HOUSE-001/003 | UC3, UC5, UC12 | 3분류, 공유 요청 | `routine_items`(category=household), `household_requests`(+items) | `GET /household/today` + `POST/GET /family/household-requests`,`.../confirm`,`.../complete` | `test_guide_query.py`(조회), `test_family_household_request.py`(6개: 생성→확인→완료 영속화, 미연동 409, 타인 403, 완료 후 재확인 409, 목록, 503) | PASS |
| Wife | W-HEALTH-001 | FUC-W-HEALTH-001/002 | UC3, UC6, UC11 | 부위 부담, 완료 체크 | `routine_items`(category=health) | `GET /health/today` + `PUT /care/routine-items/{id}/execution` | `test_guide_query.py`, `test_care_report.py::RecordApiTest`(6개) | PASS |
| Wife | W-SLEEP-001(본문+팝업, 병합) | FUC-W-SLEEP-001/001-1/002 | UC3, UC11, UC12 | 수면 가이드, 환경 override | `routine_items`(category=sleep), `recommendation_feedback`(MISSING) | `GET /sleep/today` + `PUT /care/routine-items/{id}/sleep-environment` | `test_guide_query.py`(조회), `test_backend_skeleton.py::test_routine_item_feedback_and_sleep_environment_echo_request_only`(Stub) | PARTIAL |
| Wife | B-CAL-001(Wife) | FUC-B-CAL-001 | UC7, UC10 | 날짜별 컨디션 색상, 실행 루틴 | `daily_conditions`+`daily_reports`(VIEW, 저장 없음) | `GET /care/calendar/{month}` | `test_care_report.py::CalendarApiTest` | PASS |
| Wife | W-REPORT-001 | FUC-W-REPORT-001/001-1/002 | UC7 | 실행 통계, 최다 부담 부위, 가족 분담 | `daily_reports`(확정 시만 저장) | `POST .../preview`,`.../finalize`,`GET .../{date}` | `test_care_report.py::ReportApiTest`(7개, funnel 집계 포함) | PASS |
| Wife | B-MOTION-001(Wife) | FUC-B-MOTION-001 | UC13 | ON/OFF, 누적시간, 알림 | `posture_calibration_profiles`/`posture_events`(Protected)+`motion_consents` | `WS /movement/live/stream`,`GET /live,/events,/report/daily` + `GET/PUT/DELETE /family/motion/*` | `test_movement_api.py`(WS 5 + 동의 게이트 4 + 남편 분기 3), `test_movement_supabase_store.py`, `test_family_motion_consent.py`(8개) | PASS — WS 연결 시 동의/수집 검사(STEP 18). Frontend는 여전히 Mock |
| Wife | W-CALLBACK-001 | FUC-W-CALLBACK-001 | UC11 | 재시도, 폴백 | `daily_routines.source` | `POST /routine/today`(재호출) | `test_routine_service.py::RoutineServiceTest`(폴백 3종) | PASS |
| Wife | W-MENU-001 | FUC-W-MENU-001 | UC1(연계) | 프로필 요약, 연동 상태 | `pregnancy_profiles`+`partner_links` | `GET /profile/me` + `GET /account/partner-link` | `test_profile.py`, `test_account_partner_link.py` | PASS |
| Wife | W-SETTING-001 | FUC-W-SETTING-001 | — | 없음(기기 로컬 저장, 계정 동기화 없음 — `04_1_기능요구사항명세서.md:133`) | — | 없음 | — | NOT_APPLICABLE |

## Trace Table — Husband

| Actor | Screen | FUC | Use Case | Data | DB | API | Test | Status |
|---|---|---|---|---|---|---|---|---|
| Husband | B-ENTRY-001(초대 수락) | FUC-H-INVITE-001 | UC16 | 토큰 검증, 계정 연동 | `partner_invitations`+`partner_links` | `POST /account/partner-invitations/{token}/accept` | `test_account_partner_link.py::InvitationLifecycleTest`(6개) | PARTIAL — API는 PASS 수준, 화면·인증 복귀 흐름은 여전히 미확정. 2026-09-20 팀 결정으로 실사용 연동은 `partner_links` 수동 삽입으로 대체(신규 연동을 이 API 경로에 의존하지 않음) |
| Husband | B-CAL-001(Husband) | FUC-B-CAL-001 | UC7, UC10 | 날짜별 기록 조회(읽기전용) | Wife B-CAL-001과 동일 | `GET /care/calendar/{month}` | `test_care_report.py::CalendarApiTest`(연동 남편→아내 캘린더, 미연동→빈 캘린더) | PASS — `partner_links`로 연동된 남편은 아내 캘린더 읽기 전용 조회(STEP 17). 쓰기 API가 없어 수정 금지는 자동 충족 |
| Husband | H-NOTI-001 | FUC-H-NOTI-001/002 | UC8, UC9, UC14 | 알림 목록 | `notifications` | `GET /family/notifications`,`POST .../read` | `test_family_notification.py`(9개: 생성·격리·읽음·404·최신순·503, 루틴 생성 알림 3종), `test_routine_service.py`(첫 생성/재생성 알림 4개) | PASS — 알림 3종 전부 발송: 가사 요청, 오전 리포트(첫 루틴 생성), 루틴 변경(재생성) |
| Husband | H-REPORT-001 | FUC-H-REPORT-001 | UC8 | 주차, 컨디션 요약, 가이드 요약 | `partner_links`+`pregnancy_profiles`+`daily_conditions`+`routine_items`(projection) | `GET /family/morning-reports/{date}` | `test_family_morning_report.py`(5개) | PASS |
| Husband | H-REQUEST-001 | FUC-H-REQUEST-001/002 | UC9 | 요청 확인/완료 | `household_requests`(+items) | `GET .../household-requests/{id}`,`.../confirm`,`.../complete` | `test_family_household_request.py` | PASS |
| Husband | H-REQUEST-002 | FUC-H-REQUEST-003 | UC9 | 완료 결과 요약 | 위와 동일 | `complete` 응답 재사용 | 위와 동일 | TBD — 화면설계서 원문에 본문 섹션 자체가 없음 |
| Husband | B-MOTION-001(Husband) | FUC-B-MOTION-001 | UC13 | 조회 전용 누적시간 | `posture_events`(Protected) | `GET /movement/events,/report/daily` | `test_movement_api.py`(연동 남편→아내 이벤트·리포트, 미연동→빈 결과), `test_partner_scope.py` | PASS — `partner_links` 연동 시 아내 데이터 읽기 전용(STEP 18) |

---

## 부가 검증

### 1. 중복 Table 여부

`docs/backend/DB_SCHEMA_RECONCILIATION.md`·`TARGET_DB_SCHEMA.md` 기준 재확인 — **중복 테이블 없음**. 17개 테이블(KEEP 7 + NEW 10) 전부 유일한 목적을 가지며, "화면 DB스키마" PDF가 제시한 것처럼 보이는 항목도 전부 `routine_items`(category 구분)나 조회 조합(Calendar)으로 흡수했다(STEP 2, STEP 11).

### 2. 중복 Column 의미 여부

- `posture_calibrations`(ERD 문서 표기) vs `posture_calibration_profiles`(실제 테이블명) — 같은 테이블을 가리키는 **문서 표기 오차**, 별도 테이블 아님(STEP 4/7에서 확인, 코드 기준으로 문서만 갱신 필요로 남김).
- `routine_items.source_ids` — ERD 문서 표에는 없었지만 실제 migration에는 있음(문서가 stale, 컬럼 자체는 정상).
- `household_requests.status`/`household_request_items.status` 값 — 원래 DB_ERD_스키마.md 초안(`requested/confirmed/done`)과 실제 코드(`unconfirmed/confirmed/completed`)가 달라 STEP 7에서 코드 기준으로 정정(§DB_SCHEMA_RECONCILIATION.md 이미 기록).
- `notifications.type` — ERD 초안 4종 vs 실제 코드 3종, 코드 기준으로 정정(STEP 7).
- 그 외 컬럼명 중복/충돌 없음.

### 3. Actor별 권한

- 아내: 본인 `user_id` 기준으로만 모든 데이터 접근(Condition/Profile/Routine 전부 `.eq("user_id", user_id)`로 스코프, `test_care_condition.py::test_users_do_not_see_each_others_conditions`로 검증).
- 남편: `partner_links` 확인 후에만 아내 데이터의 **파생 요약**을 읽는다(원본 접근 경로 없음). `test_family_morning_report.py`가 미연동(403)·타인 연동(403)·원본 미노출을 검증.
- 가사 요청: 요청 소유자(아내)와 수신자(남편)만 접근·상태 변경 가능(`family/service.py::_authorized_request/_partner_request`).
- 프로필: 어떤 API도 타인의 `user_id`를 매개변수로 받지 않는다(STEP 10 `test_husband_cannot_read_wifes_profile`로 재확인).

### 4. RLS

전체 17개 테이블(7 KEEP + 10 NEW) 모두 `enable row level security` + 정책 없음(service role만 접근) 확인 — STEP 7 migration 9건 전수 검사(`create table` 수 == `enable row level security` 수, §위 명령 결과 일치). Frontend는 anon key로 어떤 테이블도 직접 조회하지 않는다(STEP 15, `ApiClient`가 유일한 통로).

### 5. 민감정보

- 컨디션 원본 점수, 프로필 원본, AI 대화 원문 — 남편 응답 Schema 어디에도 필드 자체가 없음(`test_family_morning_report.py::test_response_never_contains_profile_or_chat_fields`로 필드 집합을 통째로 검증).
- 오전 리포트의 `condition_summary`는 원본 점수 대신 "높음" 정성 문구만 노출(계산식은 TBD로 명시, 지어내지 않음).
- Movement: 카메라 프레임·영상·landmark는 어디에도 저장하지 않음(`test_family_motion_consent.py`의 `PostureEvent`/`CalibrationProfileSchema` 필드 검사로 재확인, STEP 14).
- 컬럼 단위 암호화(Vault/pgsodium)는 여전히 TBD(`DB_ERD_스키마.md` §4, 이번 STEP에서도 새로 결정하지 않음).

### 6. Routine regression

`app/services/routine/**`, `app/api/v1/routine.py` **미수정 확인**(전체 STEP 0~15 동안 `git diff`에 해당 경로 없음). 관련 테스트 `test_routine_prompt.py`, `test_routine_rules.py`, `test_routine_service.py` 전부 통과(위 117개 중 포함). STEP 12·STEP 16에서 `generate_daily_report()`/`EventStore`/`repository.get_routine()`을 **호출만** 하고 내부를 바꾸지 않았음을 재확인.

### 7. Movement regression

`app/services/movement/**`, `app/api/v1/movement.py` **미수정 확인**. `test_movement_api.py`(WebSocket 프로토콜 5종), `test_movement_supabase_store.py`(Calibration/Event Store 9종), `test_report.py`(리포트 집계 8종) 전부 통과. STEP 14에서 `motion_consents`(Family 소관)만 신규 연결했고 Protected 테이블(`posture_events`/`posture_calibration_profiles`)과 알고리즘은 그대로다.

### 8. Frontend Contract

STEP 15에서 `Widget → Store → Repository 인터페이스 → (Mock|Api)Repository → ApiClient → Backend` 경계를 Condition 화면에 실제로 구현하고 테스트로 증명(`condition_repository_test.dart` 7개). `ApiClient`는 Supabase Table을 직접 조회하지 않고 Backend REST만 호출한다. 나머지 30개 화면은 `docs/frontend/API_INTEGRATION_STATUS.md`에 MOCK_ONLY로 기록돼 있으며 UI는 전혀 바꾸지 않았다(기존 UI/디자인 불변 원칙 유지).

### 9. Migration 순서

`supabase/migrations/*.sql` 15개 파일, 타임스탬프 접두어 기준 정렬이 실제 적용 순서와 일치(`20260915000000`~`20260917010800`, 파일명 lexical 정렬 = 시간 순 정렬 확인). STEP 7에서 추가한 9개는 기존 6개(`20260915000000`~`20260917000002`) 뒤에 정확히 이어지며, 기존 migration은 **단 한 번도 수정하지 않았다**(모든 STEP에서 `ALTER`/신규 파일만 사용).

---

## Domain별 최종 상태

| Domain | 상태 | 근거 |
|---|---|---|
| Profile | **PARTIAL** | 기존 1~6단계 계약은 PASS지만 최신 FUC-W-PROFILE-002에 복구된 생년월일을 Supabase 단계 API와 `pregnancy_profiles`에 반영해야 함 |
| Condition | **READY** | Create/Read/Update/검증/인증/격리/KST 경계까지 전부 테스트로 커버(STEP 9) |
| Routine / Routine Item(Routine AI 소유) | **READY** | 미수정 확인, 기존 테스트 전부 통과. AI 실호출 1회만 OpenAI 크레딧 대기(기능 결함 아님, 외부 자원 문제) |
| Meal / Household(조회) / Health / Sleep(조회) — Guide Query | **READY** | 4개 API 전부 실 연결·테스트 완비(STEP 11), AI 재호출 없이 `routine_items` 읽기 전용 |
| Record | **READY** | `routine_items` 직접 갱신, 별도 로그 테이블 없이 완결(STEP 12) |
| Report / Calendar | **READY** | `family` 집계를 `household_requests` 실조회로 교체, 남편 캘린더 읽기 전용 분기 추가(STEP 17) |
| Household(요청·상태전이) | **READY** | `household_requests`/`household_request_items` 실 연결, 생성→확인→완료 전이·권한·409/403 테스트 완비(STEP 17) |
| Family/Relationship(연동) | **READY** | bootstrap·partner-link·초대 발급/수락 전부 실 DB, 72시간·1회성·중복연동 거절까지 테스트 완비(STEP 13) |
| Notification | **READY** | `notifications` 실 연결. 발송 트리거 3종(가사 요청/오전 리포트/루틴 변경) 전부 구현·테스트(STEP 17). 오전 리포트·루틴 변경 알림은 `POST /routine/today` 성공 직후 발송(FUC-W-COND-002/003) |
| Report(남편 오전) | **READY** | family authorization + projection 원칙으로 완결, 원본 비노출 검증까지 포함(STEP 12) |
| Chat | **BLOCKED** | 지원 테이블 없음(NFR-027 보관 정책 자체가 TBD라 실 연결의 전제조건이 아직 없음) |
| Movement(Protected) | **READY** | 알고리즘·핵심 데이터 흐름 불변, 전체 회귀 테스트 통과. STEP 18에서 동의↔WS 게이트 연동·남편 조회 분기 완료(라우트 계층만 수정, `services/movement/**` 불변). 임계값은 데모값으로 MVP 확정 |
| Motion Consent | **READY** | `motion_consents` 실 연결, 카메라 데이터 미저장 재확인(STEP 14) |
| Frontend Integration | **PARTIAL** | 아키텍처 경계와 패턴은 READY 수준(Condition 1개 화면 증명 완료)이나 나머지 30개 화면은 여전히 MOCK_ONLY — 화면별 로딩/오류 UI 추가가 남은 선행 작업 |

### 전체 요약

STEP 16 시점 **READY 9 / PARTIAL 2 / BLOCKED 3** → STEP 17 시점 **READY 12 / PARTIAL 1 / BLOCKED 1** (Domain 14개 기준). Household·Notification이 BLOCKED에서 READY로, Report/Calendar가 PARTIAL에서 READY로 올라갔다(가족 분담 집계는 "자동 해소"가 아니라 `care/supabase_repository.py`의 하드코딩 0을 `household_requests` 조회로 직접 교체해야 했다). 남은 BLOCKED는 Chat 1개(AI 담당 영역, NFR-027 TBD), PARTIAL은 Frontend Integration 1개다. STEP 18에서 Movement의 남은 두 항목(동의↔WS 게이트, 남편 조회 분기)을 소유자가 직접 마무리해 B-MOTION-001 아내/남편 행 모두 PASS가 됐다.
