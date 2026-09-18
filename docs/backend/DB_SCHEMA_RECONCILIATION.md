# DB Schema Reconciliation

- 작성일: 2026-09-17
- 이 문서는 분석 결과이며 이 단계에서 실제 migration·코드는 변경하지 않았다.

## 전제: "화면 DB스키마" PDF의 실체

`docs/requirements/아내 화면 DB스키마.pdf`, `docs/requirements/남편 화면 DB 스키마.pdf`는 파일명과 달리 테이블/컬럼/타입/PK/FK 표기가 없는 **화면별 필드·상태값 명세서**다. 두 문서 모두 "테이블", "컬럼" 같은 표현이나 ERD가 없고, 화면 ID(`W-PROFILE-002`, `H-REQUEST-001` 등) 단위로 입력/표시 필드와 저장 여부(저장 데이터/계산 데이터)만 서술한다.

따라서 이 문서의 `Proposed Table` 열은 PDF가 직접 제시한 표가 아니라, PDF가 서술한 화면별 데이터 요구사항을 실제 Backend 팀이 이미 설계해 둔 구 ERD 초안(삭제됨)(근거: 04_1/04_2/화면설계서/개발순서/실 코드)의 테이블에 매핑한 결과다. 현재 목표 스키마는 `docs/backend/TARGET_DB_SCHEMA.md`. 초안은 이미 "같은 데이터를 Actor별로 중복 저장하지 않는다", "Calendar는 조회 조합으로 처리한다", "Routine 결과와 중복되는 데이터는 신규 테이블 대신 `routine_items`로 해결 가능한지 확인한다" 등 이번 분석에서 요구한 원칙을 반영해 작성돼 있었다 — 새 테이블을 여기서 추가 제안하지 않고, 기존 설계 대비 실제 migration 적용 여부만 대조했다.

두 PDF의 화면 간 중복(같은 데이터를 아내/남편 문서가 각자 서술)도 확인했다: `B-CAL-001`, `B-MOTION-001`은 두 문서 모두에 등장하지만 필드가 아니라 **권한 범위**(아내는 수정 가능, 남편은 조회만)만 다르다 — 데이터 중복 저장 위험이 아니라 접근 제어 문제로 판단해 별도 테이블을 만들지 않았다.

## 범례

- **Status**: `EXISTING_MATCH`(기존 테이블과 일치) / `EXISTING_DIFFERENT`(기존 테이블이 있으나 이름·제약이 다름) / `MISSING`(제안된 테이블이 아직 없음) / `DERIVED_NOT_STORED`(저장하지 않고 조회 시 계산) / `DUPLICATE_RISK`(중복 저장 위험 플래그) / `TBD`
- **Action**: 다음 단계에서 필요한 조치. 이 문서 자체는 어떤 조치도 실행하지 않는다.

## 화면별 데이터 → 테이블 대조표

| Actor | Screen | Data | Proposed Table | Existing Table | Status | Action |
|---|---|---|---|---|---|---|
| Both | B-ENTRY-001 | 역할, 표시 이름 | `profiles` | 없음 | MISSING | 신규 migration (role/display_name) |
| Wife | W-PROFILE-001 | 출산예정일, 마지막 생리 시작일 | `pregnancy_profiles` | `pregnancy_profiles`(EXISTING, `20260915000000` + `20260916000000_relax_due_date_constraint`) | EXISTING_MATCH | 없음 |
| Wife | W-PROFILE-002 | 신장, 임신 전 체중 | `pregnancy_profiles.height_cm/pre_pregnancy_weight_kg` | 동일 컬럼 존재 | EXISTING_MATCH | 없음 |
| Wife | W-PROFILE-002 | 생년월일→나이 | — | 컬럼 없음. 최신 FUC-W-PROFILE-002에서 필수 입력으로 복구 | GAP | `birth_date` 컬럼 migration 및 단계 API Request/Response 확장 |
| Wife | W-PROFILE-003 | 초산/경산 | `pregnancy_profiles.is_first_pregnancy` | 존재(`20260917000001_routine_tables`) | EXISTING_MATCH | API만 연결 필요(DB는 준비됨) |
| Wife | W-PROFILE-004 | 단태/쌍태 | `pregnancy_profiles.is_multiple_pregnancy` | 존재 | EXISTING_MATCH | API만 연결 필요 |
| Wife | W-PROFILE-005 | 알레르기 다중선택 | `pregnancy_profiles.allergies` | 존재(`text[] default '{}'`) | EXISTING_MATCH | API만 연결 필요 |
| Wife | W-PROFILE-006 | 주의 진단, 자유 텍스트 | `pregnancy_profiles.medical_conditions/medical_note` | 존재 | EXISTING_MATCH | API만 연결 필요 |
| Wife | W-INVITE-001 | 초대 토큰, 만료시각, 사용여부 | `partner_invitations` | 없음 | MISSING | 신규 migration (NFR-026: 1회성·72시간 만료 제약 포함) |
| Wife/Husband | (연동 완료 상태) | 아내-남편 연결 | `partner_links` | 없음 | MISSING | 신규 migration (unique(husband_user_id)로 중복 연동 방지) |
| Wife | W-COND-001 | 입덧/허리/골반/다리/손목/피로/기분 | `daily_conditions` | 존재(`20260917000001_routine_tables`) | EXISTING_MATCH | Care Stub → 이 테이블 연결로 교체 |
| Wife | W-TASK-001 | 예정 활동(9종+직접입력) | `daily_conditions.planned_activities` | 존재 | EXISTING_MATCH | 위와 동일 |
| Wife | W-HOME-001 / W-MEAL-001/002 / W-HOUSE-001 / W-HEALTH-001 / W-SLEEP-001 | 루틴 원본, 항목별 payload | `daily_routines`, `routine_items` | 존재(`20260917000001_routine_tables`) | EXISTING_MATCH | 없음 (Protected: routine 서비스 수정 금지) |
| Wife | (routine_items 실제 컬럼) | `source_ids`(RAG 근거) | 구 ERD 초안(삭제됨)의 `routine_items` 표에는 미기재 | migration에는 `source_ids bigint[]` 존재 | EXISTING_DIFFERENT | 조치 불필요(초안 삭제, migration이 기준) |
| Wife | W-CHAT-001 (식사 재추천/공통 챗봇) | 대화 이력, suggested_actions | `chat_messages` | 없음 | MISSING | 신규 migration. NFR-027(보관·파기 기준 TBD, 원문 미저장) 먼저 확정 필요 |
| Wife | W-MEAL-002/W-CHAT-001, W-SLEEP-001 팝업 | 메뉴 수락/거절, 수면 환경 override 이력 | `recommendation_feedback` | 없음 | MISSING | 신규 migration |
| Wife | W-HOUSE-001 | 가사 요청(이유·상태), 요청 항목 | `household_requests`, `household_request_items` | 없음 | MISSING | 신규 migration. `household_request_items.routine_item_id`는 `routine_items` FK 재사용(중복 저장 방지, 이미 설계됨) |
| Wife | W-REPORT-001 | Daily 리포트 집계(실행 통계·가족 분담·모션 요약) | `daily_reports` | 없음 | MISSING | 신규 migration. NFR-028(날짜당 1개 unique) 제약 필수 |
| Husband | H-NOTI-001 | 알림 3종(오전리포트/가사요청/컨디션변경) | `notifications` | 없음 | MISSING | 신규 migration |
| Wife | B-CAL-001 | 날짜별 컨디션 4단계 색상 | (테이블 없음) | — | DERIVED_NOT_STORED | 조회 시 `daily_conditions` 점수로 계산(신규 테이블 불필요 — 구 ERD 초안(삭제됨)도 이렇게 설계) |
| Wife | B-MOTION-001 | 동의 여부, 수집 ON/OFF | `motion_consents` | 없음. 현재 `family.py`의 `GET/PUT/DELETE /motion/*`(Stub)가 메모리로만 흉내 | MISSING | 신규 migration. WS 연결 게이트(`movement.py`)와 실제 연동 필요 |
| Wife | B-MOTION-001 | 개인 자세 기준선(baseline) | `posture_calibrations`(구 ERD 초안(삭제됨) 명칭) | `posture_calibration_profiles`(실제 migration 명칭, `20260916000000_create_movement_tables`) | EXISTING_DIFFERENT | 테이블은 있고 동작함(Protected) — 조치 불필요(초안 삭제, 실제 migration 명칭이 기준) |
| Wife | B-MOTION-001 | 세션 상태(진행중/종료, 현재 자세) | `motion_sessions` | 없음 — 현재는 `movement.py`의 전역 변수 `_current_session_id` + 프로세스 메모리(`SessionManager`)로 대체 | MISSING | `TARGET_DB_SCHEMA.md`에서 NOT_REQUIRED(이번 MVP). Protected 모듈이라 도입 여부는 별도 합의 필요 |
| Wife/Husband | B-MOTION-001 | 임계 이벤트(자세·부담라벨·지속시간) | `posture_events` | 존재(`20260916000000_create_movement_tables`), 실동작(Protected) | EXISTING_DIFFERENT | 컬럼 구성은 구 ERD 초안(삭제됨)과 대부분 일치하나 `session_id`가 FK 제약 없이 `uuid not null`로만 존재(참조 테이블 `motion_sessions`가 없어 FK를 걸 수 없는 상태) — `motion_sessions` 도입 시 함께 정리 |
| Both | (NFR-011 제약) | 프레임/33-landmark(`PostureFrameState`), 원본 영상 | — | 저장 안 함(코드·구 ERD 초안(삭제됨) 모두 명시적으로 배제) | DERIVED_NOT_STORED | 준수 확인 — NFR-011("영상 복원 가능 데이터도 포함해 저장 금지")과 충돌 없음 |

## Duplicate Data Risks (상세)

| # | 위험 | 판단 | 근거 |
|---|---|---|---|
| 1 | 프로필 저장을 `profile.py`(Supabase, 1~2단계 단계별)와 `account.py`(Stub, 6단계 일괄, `birth_date` 요구)가 이중으로 계약함 | DUPLICATE_RISK | 최신 FUC가 `birth_date`를 확정했으므로 `pregnancy_profiles` migration 후 두 계약을 하나로 통합해야 한다 |
| 2 | 컨디션 캘린더 지수를 별도 테이블에 저장 | 위험 아님(DERIVED_NOT_STORED로 이미 설계) | 구 ERD 초안(삭제됨): "캘린더 4단계 색은 조회 시 계산" |
| 3 | 모션 요약을 `daily_reports.content`에 스냅샷 저장 | 위험 아님(의도된 설계) | `posture_events` 30일 보존 만료 후에도 캘린더 과거 조회를 지원하기 위한 스냅샷 — 원본 삭제 후에도 리포트에는 남아야 하므로 목적이 다른 저장 |
| 4 | 가사 요청 항목과 루틴 항목을 각각 저장 | 위험 아님(FK 재사용으로 설계됨) | `household_request_items.routine_item_id` → `routine_items` FK. 신규 테이블 도입 시 이 FK를 지켜야 중복 저장을 피한다 |
| 5 | `posture_calibrations`(구 ERD 초안(삭제됨)) vs `posture_calibration_profiles`(실제) 이름 불일치로 인한 혼선 | DUPLICATE_RISK(문서 vs 코드) | 새 migration 작성 시 문서 명칭을 그대로 따르면 테이블이 중복 생성될 수 있음 — 반드시 실제 존재하는 `posture_calibration_profiles`를 기준으로 작업 |

## 원칙 준수 확인 (이번 분석 기준)

1. PDF에 있다고 바로 Table을 만들지 않음 — PDF 자체에 테이블 정의가 없어 해당 없음(위 "전제" 참고)
2. 기존 Table/Column이 있으면 재생성하지 않음 — `pregnancy_profiles`/`daily_conditions`/`daily_routines`/`routine_items`/`pregnancy_knowledge`/`posture_calibration_profiles`/`posture_events` 7개 모두 기존 유지, 재생성 제안 없음
3. 같은 데이터를 Actor별로 중복 저장하지 않음 — `B-CAL-001`/`B-MOTION-001`은 권한만 다르고 테이블은 공유하도록 이미 설계됨
4. Routine 결과와 중복되는 Meal/Household/Health/Sleep 데이터는 `routine_items`로 해결 가능한지 확인 — `household_request_items`가 `routine_items` FK를 재사용하도록 이미 설계됨
5. Calendar는 조회 조합으로 처리 — `DERIVED_NOT_STORED`로 확인
6. Report도 원본 데이터 중복 저장을 피함 — 모션 요약은 스냅샷 목적의 예외로 별도 판단(#3)
7. 기존 migration은 수정하지 않음 — 이번 분석에서 migration 파일을 열람만 하고 변경하지 않았음
8. 필요한 DB 변경은 신규 migration으로만 — 이 문서는 신규 migration을 제안만 하고 작성하지 않았음
9. Movement frame/video/landmark 저장 여부는 NFR과 충돌 여부 확인 — NFR-011과 실제 코드·구 ERD 초안(삭제됨) 모두 "저장 안 함"으로 일치, 충돌 없음
