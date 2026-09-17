# Backend Implementation Status

- 작성일: 2026-09-17 (STEP 1 갱신)
- 목적: 최신 요구사항(화면설계서·기능/비기능명세서·화면 DB스키마) 대비 현재 Backend 구현 상태를 화면 단위로 정리해 이후 Skeleton 구축의 기준으로 삼는다.
- 분석 순서: 화면 → FUC → Use Case → 필요한 데이터 → DB Schema → API → 현재 구현 상태.
- 이 문서는 분석 결과이며 이 단계에서 코드·migration·API는 변경하지 않았다.
- STEP 1 재검증: `git status`로 STEP 0 이후 `backend/**`, `supabase/migrations/**` 변경 없음을 확인(신규 파일은 이 문서들뿐). 실제 코드·migration을 다시 열람해 아래 상태를 재확인했다 — 문서상 DB가 존재해도 실제 migration에 없으면 IMPLEMENTED로 판단하지 않았다.

## Reference Documents

기능/화면 판단 기준(최신, 충돌 시 우선):

1. `docs/requirements/아내_화면설계서.pdf`
2. `docs/requirements/남편_화면설계서.pdf`
3. `docs/requirements/03_유스케이스명세서.md`
4. `docs/requirements/04_1_기능요구사항명세서.md`
5. `docs/requirements/04_2_비기능요구사항명세서.md`

데이터 설계 기준:

6. `docs/requirements/아내 화면 DB스키마.pdf`
7. `docs/requirements/남편 화면 DB 스키마.pdf`

서비스 흐름도(`docs/서비스흐름도/**`)는 사용하지 않았다.

> **중요 발견**: 6·7번 PDF는 파일명과 달리 실제 테이블/컬럼/타입/PK/FK 표기가 전혀 없는 **화면별 필드 명세서**다(ERD 아님). 이 문서에서 "DB 설계 기준"으로 실제 사용 가능한 자료는 화면별로 어떤 데이터가 필요한지에 대한 서술뿐이며, 실제 테이블 설계는 이미 Backend 팀이 작성한 `docs/DB_ERD_스키마.md`(근거: 04_1/04_2/화면설계서/개발순서/실제 코드)가 담당하고 있었다. 본 문서와 `DB_SCHEMA_RECONCILIATION.md`는 이 실태를 반영해 `DB_ERD_스키마.md`를 사실상의 스키마 기준선으로 쓰고, 6·7번 PDF는 화면별 "필요한 데이터" 열의 근거로만 사용한다.

현재 구현 상태 파악용 참고자료: `backend/README.md`, `docs/api.md`, `docs/DB_ERD_스키마.md`, `backend/DOMAIN_OWNERSHIP.md`, `backend/app/**`, `supabase/migrations/**`.

---

## Wife Screen Matrix

아내 화면설계서 원문은 26개 화면 블록을 담고 있으나 `W-HOME-001`(컨디션 미입력/통합 2버전), `W-CHAT-001`(식사 재추천/공통 챗봇 2버전), `W-SLEEP-001`(본문/바텀시트 팝업, 팝업 쪽은 타 문서상 W-SLEEP-002 추정)에서 화면 ID가 중복 재사용된다. 아래는 ID 기준으로 병합한 24개 고유 화면이다. `W-COND-001`은 화면설계서 원문 헤더가 "홈 — 컨디션 미입력 상태"로 `W-HOME-001`과 이름이 중복되고 본문 필드는 사실상 `W-TASK-001`(집안일 선택)과 거의 동일한 원문 오기로 보이나, 실제 컨디션 입력 기능은 `04_1_기능요구사항명세서.md`의 FUC-W-COND-001 정의를 기준으로 판단했다.

| Actor | Screen | FUC | 필요한 데이터 | DB | API | Backend 상태 |
|---|---|---|---|---|---|---|
| Wife | B-ENTRY-001 | FUC-B-ENTRY-001 | 로그인 상태, 프로필 완료 여부, 파트너 연동 상태 | `profiles`(MISSING), `pregnancy_profiles`(EXISTING) | `GET /account/bootstrap` (Stub, 메모리) | SKELETON_REQUIRED |
| Wife | W-PROFILE-001 | FUC-W-PROFILE-001 | 출산예정일, 마지막 생리 시작일 | `pregnancy_profiles`(EXISTING) | `PUT /profile/me/due-date` (Supabase 연동) | IMPLEMENTED |
| Wife | W-PROFILE-002 | FUC-W-PROFILE-002 | 신장, 임신 전 체중, (화면상) 생년월일→나이 | `pregnancy_profiles.height_cm/pre_pregnancy_weight_kg`(EXISTING). 생년월일/나이 컬럼 없음(`DB_ERD_스키마.md`가 "ProfileDraft.age는 FR에 없어 제외"로 이미 결정) | `PUT /profile/me/body` (Supabase 연동, 신장·체중만) | PARTIAL |
| Wife | W-PROFILE-003 | FUC-W-PROFILE-003 | 초산/경산 여부 | `pregnancy_profiles.is_first_pregnancy`(EXISTING, migration `20260917000001`) | 없음. `account.py`의 6단계 통합 `ProfileInput`(Stub)만 존재, 단계별 저장 라우트 없음 | SKELETON_REQUIRED |
| Wife | W-PROFILE-004 | FUC-W-PROFILE-004 | 단태/쌍태 여부 | `pregnancy_profiles.is_multiple_pregnancy`(EXISTING) | 없음(위와 동일) | SKELETON_REQUIRED |
| Wife | W-PROFILE-005 | FUC-W-PROFILE-005 | 알레르기 다중 선택 | `pregnancy_profiles.allergies`(EXISTING) | 없음(위와 동일) | SKELETON_REQUIRED |
| Wife | W-PROFILE-006 | FUC-W-PROFILE-006 | 주의 진단 다중 선택, 자유 텍스트 | `pregnancy_profiles.medical_conditions/medical_note`(EXISTING) | 없음(위와 동일) | SKELETON_REQUIRED |
| Wife | W-PROFILE-007 | FUC-W-PROFILE-007 | 1~6단계 요약, 최종 저장 | 위 컬럼 전체 | `GET/PUT /account/profile` (Stub, 메모리·`birth_date` 필수 요구로 실제 DB 컬럼과 불일치) | PARTIAL |
| Wife | W-INVITE-001 | FUC-W-INVITE-001 | 초대 토큰/URL/만료시각 | `partner_invitations`(MISSING) | `POST /account/partner-invitations` (Stub, 메모리) | DB_REQUIRED |
| Wife | W-HOME-001 (컨디션 미입력/통합 2버전 병합) | FUC-W-HOME-001, FUC-W-HOME-002 | 인사말, 주차, 컨디션 요약, 루틴 4종 요약, "일정 마치기" | `daily_conditions`(EXISTING), `daily_routines`/`routine_items`(EXISTING) | `GET /routine/today`(Supabase 연동) + `GET /care/conditions/{date}`(Stub) 혼합 | PARTIAL |
| Wife | W-COND-001 | FUC-W-COND-001 | 입덧/허리/골반/다리/손목/피로/기분 5단계 7종 | `daily_conditions`(EXISTING, migration `20260917000001`) | `PUT /care/conditions/{date}` (Stub, 메모리 — 실 테이블 미연결) | PARTIAL |
| Wife | W-TASK-001 | FUC-W-TASK-001 | 예정 활동(9종 코드+직접입력) | `daily_conditions.planned_activities`(EXISTING) | `PUT /care/conditions/{date}/activities` (Stub) | PARTIAL |
| Wife | W-MEAL-001 | FUC-W-MEAL-001 | 끼니별 추천 요약 | `routine_items`(EXISTING, category=meal) | `GET/POST /routine/today` (Supabase 연동, AI 실호출은 OpenAI 크레딧 대기) | IMPLEMENTED |
| Wife | W-MEAL-002 | FUC-W-MEAL-002 | 메뉴/이유/영양태그/주의사항 | `routine_items.payload`(meal shape, EXISTING) | `GET/POST /routine/today` | IMPLEMENTED |
| Wife | W-CHAT-001 (식사 재추천/공통 챗봇 2버전 병합) | FUC-W-MEAL-003, FUC-W-CHAT-001, FUC-W-CHAT-002 | 대화 이력, 대체 메뉴, 수락/거절 | `chat_messages`(MISSING), `recommendation_feedback`(MISSING) | 없음(Router·Service 자체가 없음) | SKELETON_REQUIRED |
| Wife | W-HOUSE-001 | FUC-W-HOUSE-001, FUC-W-HOUSE-003, FUC-W-HOUSE-003-1 | 3분류 결과, 공유 요청(이유·집안일·보조정보) | `routine_items`(EXISTING, category=household), `household_requests`/`household_request_items`(MISSING) | `POST/GET /family/household-requests` (Stub) | PARTIAL |
| Wife | W-HEALTH-001 | FUC-W-HEALTH-001, FUC-W-HEALTH-002 | 부위별 부담, 활동 추천, 완료 체크 | `routine_items`(EXISTING, category=health) | `GET /routine/today`(real) + `PUT /care/routine-items/{id}/execution`(Stub) | PARTIAL |
| Wife | W-SLEEP-001 (본문+바텀시트 팝업 병합) | FUC-W-SLEEP-001, FUC-W-SLEEP-001-1, FUC-W-SLEEP-002 | 권장 취침시간, 환경 5항목, override 이력, 가전 실행 | `routine_items`(EXISTING, category=sleep), `recommendation_feedback`(MISSING) | `GET/POST /routine/today`. override 저장·가전 실행 API 없음(ThinQ 연동 W-SLEEP-002는 Phase 2) | PARTIAL |
| Wife | B-CAL-001 | FUC-B-CAL-001 | 날짜별 컨디션 색상, 실행 루틴, 가전, 가족 분담 | `daily_conditions`/`routine_items`(EXISTING), `household_requests`(MISSING) | `GET /care/calendar/{month}` (Stub, 메모리) | SKELETON_REQUIRED |
| Wife | W-REPORT-001 | FUC-W-REPORT-001, FUC-W-REPORT-001-1, FUC-W-REPORT-002 | 실행 통계, 최다 부담 부위, 가족 분담 요약, 홈캠 주의사항 | `daily_reports`(MISSING) | `POST .../preview`, `.../finalize`, `GET .../{date}` (Stub, 메모리) | SKELETON_REQUIRED |
| Wife | B-MOTION-001 | FUC-B-MOTION-001 | ON/OFF, 오늘 누적시간, 임계값 알림 리스트 | `posture_calibration_profiles`/`posture_events`(EXISTING), `motion_consents`(MISSING) | `WS /movement/live/stream`, `GET /live,/events,/report/daily`(Supabase 연동, 실동작) + `GET/PUT/DELETE /family/motion/*`(Stub, 동의값이 WS 게이트와 미연동) | PARTIAL |
| Wife | W-CALLBACK-001 | FUC-W-CALLBACK-001 | 재시도, 전일 루틴/기본 템플릿 폴백 | `daily_routines.source`(EXISTING) | `routine.py` 내부 폴백 로직(Supabase 연동, 실동작 확인됨) | IMPLEMENTED |
| Wife | W-MENU-001 | FUC-W-MENU-001 | 프로필 요약, 남편 연동 상태 | `pregnancy_profiles`(EXISTING), `partner_links`(MISSING) | `GET /profile/me`(real) + `GET /account/partner-link`(Stub) | PARTIAL |
| Wife | W-SETTING-001 | FUC-W-SETTING-001 | 플레이스홀더 | - | 없음(문서상 "미반영, Phase 2") | PHASE_2 |

## Husband Screen Matrix

남편 화면설계서는 8개 화면 블록, 고유 화면 ID 7개(문서 자체 명시)이며 이 중 `B-ENTRY-001`/`B-CAL-001`/`B-MOTION-001` 3개는 아내 화면과 ID를 공유한다(위 표에 이미 포함, 남편 관점의 읽기 전용 권한 분기만 아래에 별도 기재). `H-REQUEST-001`은 확인/수행 2버전이 같은 ID를 쓴다.

| Actor | Screen | FUC | 필요한 데이터 | DB | API | Backend 상태 |
|---|---|---|---|---|---|---|
| Husband | B-ENTRY-001 (초대 수락 경로) | FUC-H-INVITE-001 | 초대 토큰 검증, 계정 연동 | `partner_invitations`/`partner_links`(MISSING) | 없음 — `DOMAIN_OWNERSHIP.md`에 "화면·인증 복귀 계약 미확정으로 Router 미추가"로 명시적 TBD | TBD |
| Husband | B-CAL-001 (읽기 전용) | FUC-B-CAL-001 | 날짜별 컨디션/실행/가전/분담 조회 | 위 Wife B-CAL-001과 동일 | `GET /care/calendar/{month}`(Stub) — 남편 조회 권한(부부 연동 검증) 분기 없음 | SKELETON_REQUIRED |
| Husband | H-NOTI-001 | FUC-H-NOTI-001, FUC-H-NOTI-002 | 알림 유형/요약/시각/읽음여부 | `notifications`(MISSING) | `GET /family/notifications`, `POST .../read`(Stub) | SKELETON_REQUIRED |
| Husband | H-REPORT-001 | FUC-H-REPORT-001 | 주차, 컨디션 요약, 예정 집안일, 4대 가이드 요약 — **원문 내부 모순**: 문서 내 두 버전이 "가이드 요약 포함 여부"를 서로 다르게 서술 | `daily_reports`(MISSING) | `GET /family/morning-reports/{date}`(Stub) | SKELETON_REQUIRED |
| Husband | H-REQUEST-001 (확인+수행 병합) | FUC-H-REQUEST-001, FUC-H-REQUEST-002 | 요청 상태(요청됨→확인됨→완료됨), 요청 목록 | `household_requests`/`household_request_items`(MISSING) | `POST .../confirm`, `.../complete`, `GET`(Stub) | SKELETON_REQUIRED |
| Husband | H-REQUEST-002(완료 결과) | FUC-H-REQUEST-003 | 완료 처리 요약, 캘린더 반영 | 위와 동일 | 별도 API 없음(원문에 본문 섹션 누락, `complete` 응답 재사용 추정) | TBD |
| Husband | B-MOTION-001 (조회 전용) | FUC-B-MOTION-001 | 조회 전용 누적시간/알림 | `posture_events`(EXISTING) | `GET /movement/events` 등(real)이나 부부 연동 검증(조회 권한) 로직 없음 | PARTIAL |

## Shared Screen Matrix

문서 내 동일 화면 ID가 아내·남편 두 쪽 모두에 정의되어 있고 권한/범위만 다른 3개 화면이다. 위 두 표에 이미 각자의 관점으로 기재했으며, 여기서는 액터 간 차이만 요약한다.

| Screen | 아내 관점 | 남편 관점 | 근거 |
|---|---|---|---|
| B-ENTRY-001 | 프로필 미등록 시 온보딩, 완료 시 홈 | 초대 미수락 시 초대 안내, 수락 시 캘린더 | FUC-B-ENTRY-001 |
| B-CAL-001 | 자신의 기록 조회+수정 가능 | 아내 기록 조회만, 수정 불가(화면설계서 명시) | FUC-B-CAL-001 |
| B-MOTION-001 | ON/OFF 토글, 동의 철회 가능 | 조회만, 토글/철회 불가(화면설계서 명시) | FUC-B-MOTION-001 |

이 권한 분기는 현재 `GET /movement/*`, `GET /care/calendar/*` 등에서 사용자 역할(role)별 응답 차등이 구현돼 있지 않다 — `DOMAIN_OWNERSHIP.md`도 "Account Stub의 기본 역할은 Wife"라고 명시해 남편 role 분기 자체가 아직 없다.

---

## Wife Data Requirements

프로필 6단계 전체 필드, 당일 컨디션 7종+예정활동, 루틴 4종(식사/가사/건강/수면) 원본과 항목별 payload, 가사 요청(이유·항목·보조정보), Daily 리포트 집계, 모션 동의·누적 이벤트, 남편 초대 토큰. 이 중 프로필 1~2단계·컨디션·루틴·모션 이벤트는 DB에 테이블이 있고, 나머지(3~6단계 API, 가사요청, 리포트, 초대, 챗봇)는 DB 또는 API 중 최소 하나가 없다.

## Husband Data Requirements

파트너 연동 상태, 알림 3종(오전 리포트/가사 요청/컨디션 변경), 오전 리포트 요약, 가사 요청 카드와 상태 전이, 캘린더 조회(아내 데이터 읽기 전용), 모션 조회(읽기 전용). 전부 `household_requests`, `notifications`, `daily_reports`, `partner_links`/`partner_invitations` 테이블이 없어 Stub 메모리로만 계약이 검증된 상태다.

## Shared Data

`daily_conditions`(4단계 컨디션 지수는 남편 화면에서 조회만), `routine_items`(가사 항목은 완료 상태를 남편이 갱신), `posture_events`(홈캠 누적, 남편은 조회만). 남편에게 노출 가능한 범위는 `DOMAIN_OWNERSHIP.md`가 이미 "오전 리포트·Daily 리포트·가사 요청·홈캠 공유 정보·캘린더"로 제한을 명시했고, 프로필 원본·컨디션 원본·AI 대화 원문은 Family 응답 Schema에 넣지 않기로 결정돼 있다(NFR-013과 일치).

---

## Existing DB Coverage

실제 적용된 migration 7건(`supabase/migrations/*.sql`) 기준 테이블: `pregnancy_profiles`(1~6단계 컬럼 포함), `daily_conditions`, `daily_routines`, `routine_items`, `pregnancy_knowledge`(pgvector), `posture_calibration_profiles`, `posture_events`.

`DB_ERD_스키마.md`가 제안한 18개 테이블 대비:

- **EXISTING_MATCH (7)**: `pregnancy_profiles`, `daily_conditions`, `daily_routines`, `routine_items`, `pregnancy_knowledge`, `posture_events`(컬럼은 대부분 일치)
- **EXISTING_DIFFERENT (2)**: `posture_calibrations`(ERD 명칭) vs 실제 `posture_calibration_profiles`(테이블명 불일치); `routine_items.source_ids`(migration에는 있으나 ERD 표에는 누락, 문서만 stale)
- **MISSING (9)**: 아래 Missing DB Structures 참고

상세 화면 단위 대조는 `DB_SCHEMA_RECONCILIATION.md` 참고.

## Missing DB Structures

`profiles`, `partner_invitations`, `partner_links`, `recommendation_feedback`, `chat_messages`, `household_requests`, `household_request_items`, `daily_reports`, `notifications`, `motion_consents`, `motion_sessions` — 총 11개(`DB_ERD_스키마.md`가 이미 설계했으나 migration 미적용).

## Duplicate Data Risks

1. **프로필 저장 이중 구현**: `profile.py`(Supabase 연동, 1~2단계 단계별 저장)와 `account.py`의 `PUT /account/profile`(Stub, 6단계 일괄 저장, `birth_date` 필수)이 같은 `pregnancy_profiles` 대상 데이터를 서로 다른 계약으로 다룬다. `birth_date`/`age`는 `pregnancy_profiles`에 컬럼이 없고 `DB_ERD_스키마.md`가 이미 "FR에 없어 제외"로 결정한 값이라, Account 쪽 실제 구현 시 필드 정합을 다시 맞춰야 한다.
2. **`posture_calibrations` 명칭 불일치**: ERD 문서와 실제 migration의 테이블명이 달라, 새 migration 작성 시 문서를 그대로 따르면 테이블이 중복 생성될 위험이 있다.
3. **컨디션 캘린더 지수**(위험 아님, 확인 완료): `daily_conditions` 원본 점수와 `B-CAL-001`의 4단계 색상 지수는 별도 테이블 없이 조회 시 계산으로 유지하도록 이미 설계돼 있다.
4. **모션 요약 vs 원본 이벤트**(위험 아님, 확인 완료): `daily_reports.content`의 모션 요약 스냅샷은 `posture_events` 30일 보존 만료 후에도 캘린더 과거 조회를 지원하려는 목적이라 중복 저장이 아니다.
5. **가사 요청 항목 vs 루틴 항목**(위험 아님, 확인 완료): `household_request_items.routine_item_id`가 `routine_items`를 FK로 재사용하도록 설계돼 있어 항목 원본을 중복 저장하지 않는다.

## API Gaps

- 프로필 3~6단계 저장(단계별 개별 API) — DB 컬럼은 있음
- 당일 컨디션·예정활동을 `daily_conditions` 테이블에 실제로 쓰는 API(현재 Stub이 메모리만 사용)
- 파트너 초대/연동 확정(`partner_invitations`/`partner_links` 영속화), 초대 수락(H-INVITE-001)
- 가사 요청·알림·오전 리포트·Daily 리포트 영속화(Family/Care Stub → Supabase adapter 교체)
- 챗봇(W-CHAT-001), 메뉴 수락/거절 이력, 수면 환경 override 저장
- 모션 동의(`motion_consents`)를 WS 연결 게이트에 실제로 연동
- ThinQ 가전 실행(W-HOUSE-002, W-SLEEP-002) — Phase 2/MVP 표시까지만
- 남편 조회 권한(부부 연동 검증) 분기 — `B-CAL-001`, `B-MOTION-001`, `posture_events` 조회 모두 현재 role 구분 없음

## Protected Modules

다음은 이번 분석·이후 Skeleton 구축 모두에서 수정하지 않는다.

- `backend/app/services/routine/**`, `backend/app/api/v1/routine.py`
- `backend/app/services/movement/**`, `backend/app/api/v1/movement.py`
- `backend/models/**`

## TBD

- `FUC-H-INVITE-001`: 초대 수락 화면·인증 복귀 계약 미확정 (`DOMAIN_OWNERSHIP.md` 기존 TBD)
- `FUC-W-COND-003` vs 유스케이스 UC2 A1 설명 불일치 — 최신 FUC는 "남편 변경 알림 발송"으로 명시했으나 UC 문서는 미정 (`DOMAIN_OWNERSHIP.md` 기존 TBD)
- `H-REPORT-001`(남편 화면 DB스키마 PDF): 오전 리포트에 4대 AI 가이드 요약 포함 여부가 같은 화면 ID 내 두 버전에서 서로 다르게 서술됨 — 확정 필요
- `H-REQUEST-002`(가사 요청 완료 결과): 남편 화면설계서 인덱스에는 있으나 본문 상세 섹션이 문서에 없음 — 별도 API 필요 여부 확인 필요
- Calendar 4단계 컨디션 지수 계산식, Motion 감지 임계값 — 문서상 수치 미확정 (`DOMAIN_OWNERSHIP.md` 기존 TBD)
- Account Stub의 기본 역할이 Wife로 고정 — 실제 adapter에서 인증 사용자 역할 조회 필요 (`DOMAIN_OWNERSHIP.md` 기존 TBD)
- `posture_calibration_profiles`/`posture_events`의 `motion_sessions` 연동(§5 가정 1, `/live` 조회를 DB 기반으로 전환할지) — `DB_ERD_스키마.md`가 "확인 필요한 가정"으로 명시, 미확정
