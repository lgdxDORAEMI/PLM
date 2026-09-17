# Backend Architecture (Domain / DB / API Ownership)

- 작성일: 2026-09-17 (STEP 6, 2026-09-17 2명 체제로 개정)
- 기준: `docs/backend/DATA_OWNERSHIP.md`(15개 데이터 도메인), `docs/backend/TARGET_DB_SCHEMA.md`(18개 테이블), `docs/backend/API_CONTRACT.md`/`API_IMPLEMENTATION_MATRIX.md`(42개 API).
- 목적: 확정된 Domain/DB/API를 **2명**의 Backend 작업 영역(A/B) + Shared Protected로 배분해 이후 병렬 개발과 migration 충돌을 막는다.
- 이 문서는 조직 구조 문서이며 코드를 변경하지 않는다. 기존 `backend/DOMAIN_OWNERSHIP.md`(Account/Care/Family 3분할)를 대체하는 새 배분 기준이다.
- **개정 메모**: 원래 STEP 6은 3명(User Context / Daily Experience / Relationship·Integration) 기준으로 작성했으나, 인원이 2명으로 줄어 User Context와 Daily Experience를 한 사람이 맡도록 합쳤다. 화면 그룹(User Context / Daily Experience / Relationship) 자체는 인원 수와 무관한 데이터·화면 분류이므로 이름을 바꾸지 않았다 — **누가** 어느 그룹을 맡는지만 바뀌었다. `TARGET_DB_SCHEMA.md`/`DATA_OWNERSHIP.md`/`API_CONTRACT.md`의 내용과 STEP 7에서 이미 만든 migration 9개(파일명의 `user_context`/`daily_experience`/`relationship`/`shared` 태그 포함)는 이 화면 그룹 분류를 그대로 쓰므로 변경하지 않았다.

## 1. 팀 구성

| 담당 | 이름 | 소유 화면 그룹 | 주 소유 데이터 |
|---|---|---|---|
| Developer A | Personal Experience (구 User Context + Daily Experience 통합) | Profile, Condition, Calendar, Meal, Household, Health, Sleep, Record, Report | `pregnancy_profiles`, `daily_conditions`, calendar 조회, routine 조회(소비), execution record, `daily_reports` |
| Developer B | Relationship / Integration | Family, Invitation, Join, Notification, Chat, Frontend API Integration | `partner_links`, `partner_invitations`, `notifications`, `chat_messages` |
| Shared Protected | (두 담당자 모두의 합의 필요) | Routine AI, Movement Recognition, Auth, 공통 DB Schema, 공통 migration | `daily_routines`, `routine_items`, `pregnancy_knowledge`, `posture_calibration_profiles`, `posture_events`, `auth.users` |

**왜 User Context + Daily Experience를 합쳤나**: 이 둘을 한 사람이 맡으면 아내의 "프로필 입력 → 컨디션 입력 → AI 루틴 소비 → 실행 기록 → 리포트/캘린더 조회"로 이어지는 개인 경험 파이프라인 전체를 한 사람이 끝에서 끝까지 갖게 된다. 반대로 User Context + Relationship을 합치는 방안도 있었지만, 그렇게 하면 Calendar(구 User Context)가 Report(구 Daily Experience)를 남의 소유 테이블처럼 참조해야 하는 교차 의존이 그대로 남는다(§6). Daily Experience를 Relationship과 합치는 방안도 검토했으나, Relationship은 가족 관계·인증 경계처럼 보안·권한 판단이 몰려 있는 영역이라 별도로 두는 편이 리뷰 집중도 측면에서 낫다고 판단했다.

## 2. 중요: 현재 파일 구조와 새 배분이 일치하지 않는다

`backend/DOMAIN_OWNERSHIP.md`가 정의했던 기존 3분할(`account`/`care`/`family`)은 이번 STEP 0~5 분석에서 확정한 화면 그룹(User Context / Daily Experience / Relationship)과 **경계가 다르다.** 2명 체제로 바뀌면서 `care.py`의 내부 분열은 해소됐지만, 나머지 두 파일은 여전히 두 담당자에게 걸쳐 있다:

| 기존 파일 | 걸쳐 있는 새 담당 | 근거 |
|---|---|---|
| `app/api/v1/account.py` / `domains/account/**` | **A**(profile, bootstrap의 프로필 완료 판정) + **B**(partner-link, partner-invitations, bootstrap의 연동 상태 판정) | `GET /account/profile`은 Profile 데이터(A)지만 `POST /account/partner-invitations`는 Invitation(B) |
| `app/api/v1/care.py` / `domains/care/**` | **A만(해소됨)** — conditions·calendar(구 User Context)와 routine-items execution·daily-reports(구 Daily Experience)가 이제 같은 담당자다 | 3명 체제였던 이전 버전에서는 이 파일이 A/B로 갈렸으나, 2명 체제에서는 파일 전체가 Developer A 소유로 정리된다 |
| `app/api/v1/family.py` / `domains/family/**` | **A**(household-requests) + **B**(notifications, morning-reports) + **Shared Protected**(motion privacy/consent/collection, 개념적으로 Movement Recognition 소관) | `POST /family/household-requests`는 Household(A), `GET /family/notifications`는 Notification(B), `PUT /family/motion/collection`은 Movement(Protected) |

**이번 단계에서 파일을 쪼개지 않는다.** 대신 아래 원칙으로 충돌을 막는다:

1. **신규 API(`API_CONTRACT.md`의 `[planned]` 8개)는 처음부터 새 배분 기준의 파일에 만든다** — 기존 `account.py`/`care.py`/`family.py`에 추가하지 않는다(§4의 목표 구조 참고).
2. **기존 Stub 파일을 실제 Supabase adapter로 바꾸는 작업은 테이블 단위로 쪼개 진행한다** — 예를 들어 `family.py`의 `household-requests` 엔드포인트(A 소유)를 실제로 연결하는 PR과 `notifications` 엔드포인트(B 소유)를 연결하는 PR을 분리한다. `care.py`는 이제 전부 A 소유라 이런 분리가 필요 없다.
3. **기존 파일 자체를 새 구조로 옮기는 리팩터(파일 분리)는 별도의 "구조 전용 PR"로 다루고, 관련된 담당자(A, B) 모두의 리뷰를 받는다.** 기능 추가와 파일 이동을 같은 PR에 섞지 않는다.

## 3. 데이터 도메인 배분 (`DATA_OWNERSHIP.md` 15개 기준)

| 데이터 도메인 | 담당 | Source Table | 비고 |
|---|---|---|---|
| Profile | A | `pregnancy_profiles`, `profiles`(NEW) | `profiles.role`은 bootstrap 판정에 쓰이지만 "사용자가 누구인가"라는 성격상 A 소유 |
| Condition | A | `daily_conditions` | |
| Calendar | A | (DERIVED, 조회 조합) | `routine_items`(Protected 소유 테이블)와 같은 A 소유 `daily_reports`를 함께 읽음 — 3명 체제 때 있던 A↔B 교차 의존이 이제 A 내부로 통합됨(§6) |
| Routine / Routine Item | **Shared Protected** | `daily_routines`, `routine_items` | 변경 금지, A는 읽기만 |
| Meal / Household / Health / Sleep | A | `routine_items`(category 필터, 읽기), `household_requests`/`household_request_items`(NEW, A가 쓰기), `recommendation_feedback`(NEW) | Household 관련 쓰기 테이블만 A가 소유, `routine_items` 자체는 Protected |
| Record | A | `routine_items.status/completed_by`(Protected 테이블의 컬럼을 갱신 — 스키마 변경 아니라 행 갱신이라 허용) | |
| Report | A | `daily_reports`(NEW) | 오전 리포트(H-REPORT-001, 남편 노출)도 "Report"로 A 소유 — 화면이 남편 대상이어도 데이터 성격상 A. B는 이 데이터를 남편 공유 시점에만 조회 |
| Family(연동 상태) | B | `partner_links`(NEW) | |
| Notification | B | `notifications`(NEW) | |
| Chat | B | `chat_messages`(NEW) | |
| Movement | **Shared Protected** | `posture_calibration_profiles`, `posture_events`, `motion_consents`(NEW) | `motion_consents`는 현재 `family.py`에 위치하지만 개념적으로 Movement 소관 — 변경 시 Movement 담당(Protected) 리뷰 필요 |

## 4. 목표 파일 구조(권장, 이번 단계에서 실행하지 않음)

향후 리팩터 시 지향점만 남긴다 — 지금 당장 이 구조로 옮기지 않는다.

```text
app/
├── domains/
│   ├── personal_experience/  # Developer A: profile(1~6단계 통합), condition, calendar, household, health/sleep 보조, record, report
│   ├── relationship/         # Developer B: family link, invitation, join, notification, chat
│   ├── routine/              # Shared Protected — 현재 app/services/routine/** 그대로
│   └── movement/             # Shared Protected — 현재 app/services/movement/** 그대로
└── api/v1/
    ├── profile.py             # Developer A (기존 유지, 이미 A 소유와 일치)
    ├── personal_experience.py # Developer A 신규 — condition/calendar/household/record/report를 여기로 흡수 예정(현재 care.py+family.py 일부에서 이관)
    ├── relationship.py        # Developer B 신규 — partner-link/invitation/notification/chat을 여기로 흡수 예정(현재 account.py+family.py 일부에서 이관)
    ├── routine.py              # Shared Protected — 변경 없음
    └── movement.py             # Shared Protected — 변경 없음
```

3명 체제였던 이전 버전은 `user_context.py`/`daily_experience.py`를 별도 파일로 뒀지만, 2명 체제에서는 같은 담당자(A) 소유이므로 `personal_experience.py` 하나로 합쳤다 — 억지로 파일을 둘로 유지할 이유가 없다.

## 5. API 배분 요약

전체 API 배분은 아래 표로 확인하고, 상세 계약은 `API_CONTRACT.md`를 본다.

| 담당 | API 개수 | 현재 위치(파일) | 목표 위치 |
|---|---|---|---|
| A | 24 | `profile.py`(6: me GET·due-date·body·신규 3종) + `account.py`(3: bootstrap·profile GET·profile PUT) + `care.py`(전체 10: conditions·activities·execution·daily-reports·calendar) + `family.py`(5: household-requests) | `profile.py` + 신규 `personal_experience.py` |
| B | 8 | `account.py`(3: partner-link·invitations POST·invitations accept) + `family.py`(3: notifications·notifications read·morning-reports) + 신규 chat(2) | 신규 `relationship.py` |
| Shared Protected | 10 | `routine.py`(2) + `movement.py`(4) + `family.py`(4: motion privacy/consent/collection, `family.py` 위치지만 소유는 Protected) | 변경 없음(routine/movement), motion 4개는 향후 `relationship.py`/`personal_experience.py` 이관 시에도 Protected 리뷰 유지 |

합계 24+8+10=42로 `API_IMPLEMENTATION_MATRIX.md`의 전체 개수와 일치한다(계산 과정에서 그 문서의 `GET/PUT /account/profile` 한 행을 GET/PUT 두 행으로 분리해 셈이 어긋났던 것을 함께 바로잡았다 — 다른 모든 GET/PUT 쌍과 같은 방식). **A가 B보다 API 개수가 3배 많다(24 vs 8)** — 사용자가 이 배분(User Context+Daily Experience를 A로, Relationship을 B로)을 확인해 확정했다. 실제 작업량은 API 개수만으로 판단하지 않는다: B가 맡은 Chat(완전 신규 기능, NFR-027 정책 확정 필요)과 Relationship 전반(가족 관계·인증 경계 등 보안 민감 로직)은 개수 대비 복잡도가 높다. 개수 불균형이 실제로 부담이 크다면, A 내부에서 Daily Experience 쪽(Meal/Household/Health/Sleep/Record/Report — `care.py`의 execution·daily-reports 6개 + `family.py`의 household-requests 5개, 합계 11개)을 3순위 인원이나 다음 채용 시 우선 분리 후보로 남겨 둔다.

(A의 `GET /account/bootstrap`은 프로필 완료 판정 로직이 핵심이라 A 카운트에 포함했지만, 응답의 `partner_link` 필드는 B 소유 데이터를 읽는다 — 아래 §6 교차 의존 참고.)

## 6. 교차 의존(Cross-domain read) 목록

쓰기 소유권은 겹치지 않지만, 읽기는 자연스럽게 다른 담당의 테이블을 참조한다. 이는 충돌이 아니라 정상적인 조회 조합(VIEW)이므로 별도 승인 없이 진행하되, **스키마를 바꿔야 한다면 반드시 원래 소유자와 협의한다.**

- A의 `GET /account/bootstrap` → B 소유 `partner_links` 읽기
- A의 Household → B 소유 `partner_links`(요청 대상 남편 확인) 읽기
- A의 Report(`daily_reports.content`) → Protected `posture_events` 집계 스냅샷 포함
- B의 Notification → A의 트리거 대상 데이터(컨디션 변경, 가사 요청 상태) 참조
- B의 오전 리포트 조회(`GET /family/morning-reports/{date}`) → A 소유 `daily_conditions`/`routine_items`/`daily_reports` 읽기(남편 공유 시점에만, `partner_links` 확인 후)

3명 체제였던 이전 버전에 있던 "A의 Calendar → B 소유 daily_reports 읽기"는 이제 둘 다 A 소유라 교차 의존 목록에서 빠졌다.

## 7. Protected 모듈(합의 없이 변경 금지)

- `backend/app/services/routine/**`, `backend/app/api/v1/routine.py`
- `backend/app/services/movement/**`, `backend/app/api/v1/movement.py`
- `backend/models/**`
- `backend/app/core/security.py`(Auth) — A/B 누구의 화면 그룹도 아니므로 별도 승인 없이 인증 로직을 바꾸지 않는다
- 공통 DB Schema(`daily_routines`, `routine_items`, `pregnancy_knowledge`, `posture_calibration_profiles`, `posture_events`) 및 이들을 다루는 migration

세부 운영 규칙(PR·migration 단위, 승인 절차)은 `docs/development/BACKEND_COLLABORATION.md`에 정의한다.
