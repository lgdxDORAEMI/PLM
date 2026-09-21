# Screen / Data / API Mapping

- 작성일: 2026-09-17 (STEP 3)
- 목적: 화면마다 "무엇을 표시 → 어떤 데이터 필요 → 어디 저장 → 어떤 API"를 연결한다. Action 단위(조회/저장/트리거/네비게이션)로 쪼갠다.
- 기준: `docs/backend/BACKEND_STATUS.md`(화면-FUC-DB-API), `docs/backend/DATA_OWNERSHIP.md`(Source of Truth), 실제 `backend/app/api/v1/**` 라우트.
- 이 단계에서는 코드를 수정하지 않는다.

## API 설계 원칙 (이 문서에서 지킨 것)

1. **API는 화면이 필요로 하는 DTO를 제공하고, Backend 테이블 이름을 그대로 노출하지 않는다.** 예: `W-MEAL-001`은 `routine_items(category=meal)`이 Source Table이지만 API는 `GET /api/v1/meals/today`이며 응답 DTO의 `items[]` 필드로 내려준다(STEP 11) — URL/응답 어디에도 `routine_items`라는 이름이 없다.
2. **실제로 이미 구현된 API는 그 경로를 그대로 사용한다.** `account`/`care`/`family`/`profile`/`routine`/`movement` 6개 라우터의 기존 경로 중 테이블명을 노출하는 것은 하나도 없었다(전수 확인 완료) — 새로 이름을 바꾸지 않는다.
3. **아직 없는 API만 신규 제안하며, 기존 경로의 네이밍 컨벤션(도메인 prefix + 리소스명)을 따른다.** 표에서 `[제안]`으로 표시한다. 나머지는 `docs/api.md`/실제 라우터에 이미 있는 `[기존]` 경로다.
4. **단순 Navigation(화면 전환만 하는 버튼, 팝업 닫기, 약관 링크 등)에는 API를 만들지 않는다.** 표에서 `Navigation-only`로 표시하고 API 열은 `—`로 둔다.
5. **ThinQ 가전 실행(Phase 2)은 API를 제안하지 않는다.** 표시까지만 MVP 범위이므로 API 열은 `Phase 2 — 미제안`으로 둔다.
6. **`movement.py`는 Protected, `routine.py`는 Routine AI 담당 소유(2026-09-18 개정)라 이 문서도 새 엔드포인트를 그 파일에 추가하는 것을 전제하지 않는다.** (STEP 11 갱신) 원래는 식사/가사/건강/수면 화면이 `GET /api/v1/routine/today` 응답을 Frontend가 카테고리로 나눠 쓰는 것을 그대로 계약으로 삼았으나, STEP 11에서 화면별 조회 전용 Query Layer(`GET /api/v1/meals/today`, `/household/today`, `/health/today`, `/sleep/today`)를 별도로 구현했다 — `routine.py`는 여전히 손대지 않고, 새 `app/domains/guide/`+`app/api/v1/guide.py`가 `routine_items`(Routine AI 소유 테이블)를 읽기만 한다. 이 쪽이 실행 상태(완료 체크)까지 최신으로 반영해 더 정확하다(`daily_routines.response`는 AI가 처음 생성한 시점의 스냅샷이라 이후 완료 체크가 반영되지 않음).

---

## Wife Screen / Data / API Mapping

| Actor | Screen | Action | Data | Source Table | API | FUC |
|---|---|---|---|---|---|---|
| Wife | B-ENTRY-001 | 진입 분기 판정(조회) | role, 프로필 완료 여부, 파트너 연동 상태 | `profiles`(MISSING), `pregnancy_profiles`, `partner_links`(MISSING) | `GET /api/v1/account/bootstrap` [기존] | FUC-B-ENTRY-001 |
| Wife | B-ENTRY-001 | "시작하기" 배너 탭 | — | — | Navigation-only(bootstrap 응답의 destination대로 이동) | — |
| Wife | W-PROFILE-001 | 조회(이어하기 값 프리필) | due_date, last_period_start | `pregnancy_profiles` | `GET /api/v1/profile/me` [기존] | FUC-W-PROFILE-001 |
| Wife | W-PROFILE-001 | 저장("다음") | due_date, last_period_start | `pregnancy_profiles` | `PUT /api/v1/profile/me/due-date` [기존] | FUC-W-PROFILE-001 |
| Wife | W-PROFILE-002 | 저장("다음") | height_cm, pre_pregnancy_weight_kg | `pregnancy_profiles` | `PUT /api/v1/profile/me/body` [기존] | FUC-W-PROFILE-002 |
| Wife | W-PROFILE-002 | 생년월일 입력→나이 계산 | birth_date/age | 컬럼 없음 | 없음 — 최신 FUC-W-PROFILE-002 반영을 위한 DB migration·단계 API 확장 필요 | FUC-W-PROFILE-002 |
| Wife | W-PROFILE-003 | 저장("다음") | is_first_pregnancy | `pregnancy_profiles` | `PUT /api/v1/profile/me/pregnancy-history` [제안] | FUC-W-PROFILE-003 |
| Wife | W-PROFILE-004 | 저장("다음") | is_multiple_pregnancy | `pregnancy_profiles` | `PUT /api/v1/profile/me/pregnancy-history` [제안, 003과 같은 리소스] | FUC-W-PROFILE-004 |
| Wife | W-PROFILE-005 | 저장("다음") | allergies[] | `pregnancy_profiles` | `PUT /api/v1/profile/me/allergies` [제안] | FUC-W-PROFILE-005 |
| Wife | W-PROFILE-006 | 저장("다음") | medical_conditions[], medical_note | `pregnancy_profiles` | `PUT /api/v1/profile/me/medical-notes` [제안] | FUC-W-PROFILE-006 |
| Wife | W-PROFILE-007 | 조회(1~6단계 요약 표시) | 위 전체 필드 | `pregnancy_profiles` | `GET /api/v1/profile/me` [기존] | FUC-W-PROFILE-007 |
| Wife | W-PROFILE-007 | "완료하고 시작하기" | — | — | Navigation-only(각 단계에서 이미 저장 완료, 신규 저장 API 불필요) | FUC-W-PROFILE-007 |
| Wife | W-PROFILE-007 | 요약 행 탭(수정) | — | — | Navigation-only(해당 단계 화면 이동) | — |
| Wife | W-INVITE-001 | "초대하기" | invitation token/url/expires_at | `partner_invitations`(MISSING) | `POST /api/v1/account/partner-invitations` [기존, Stub] | FUC-W-INVITE-001 |
| Wife | W-INVITE-001 | "나중에" | — | — | Navigation-only | — |
| Wife | W-HOME-001 | 조회(홈 진입/새로고침) | 인사말·주차(파생)·컨디션 요약·루틴 4종 요약 | `pregnancy_profiles` + `daily_conditions` + `daily_routines`/`routine_items` | `GET /api/v1/routine/today` [기존] + `GET /api/v1/care/conditions/{date}` [기존, Stub] 조합 | FUC-W-HOME-001 |
| Wife | W-HOME-001 | "오늘의 일정 마치기" | 실행 통계 집계 | `daily_conditions`+`routine_items`+`posture_events`(조회조합) | `POST /api/v1/care/daily-reports/{date}/preview` [기존, Stub] | FUC-W-HOME-002 |
| Wife | W-HOME-001 | 컨디션 요약 "수정" 탭 | — | — | Navigation-only(W-COND-001 이동) | — |
| Wife | W-COND-001 | 조회(기존 값 프리필) | 입덧/허리/골반/다리/손목/피로/기분 | `daily_conditions` | `GET /api/v1/care/conditions/{date}` [기존, Stub] | FUC-W-COND-001 |
| Wife | W-COND-001 | 저장 | 위 7종 점수 | `daily_conditions` | `PUT /api/v1/care/conditions/{date}` [기존, Stub] | FUC-W-COND-001 |
| Wife | W-TASK-001 | 저장(활동 선택) | planned_activities[] | `daily_conditions.planned_activities` | `PUT /api/v1/care/conditions/{date}/activities` [기존, Stub] | FUC-W-TASK-001 |
| Wife | W-TASK-001 | "AI 하루루틴 만들기" | 루틴 생성 요청 | `daily_routines`/`routine_items` | `POST /api/v1/routine/today` [기존] | FUC-W-ROUTINE-001(트리거) |
| Wife | W-MEAL-001 | 조회(끼니 요약) | routine_items 중 meal 카테고리 | `routine_items`(category=meal) | `GET /api/v1/meals/today` [기존, STEP 11] | FUC-W-MEAL-001 |
| Wife | W-MEAL-001 | 끼니 탭 | — | — | Navigation-only(W-MEAL-002 이동) | — |
| Wife | W-MEAL-002 | 조회(메뉴 상세) | meal payload(메뉴/이유/영양태그/주의사항) | `routine_items.payload`(meal) | `GET /api/v1/meals/today`(`items[].payload`) [기존, STEP 11] | FUC-W-MEAL-002 |
| Wife | W-MEAL-002 | "AI 재조정" 탭 | — | — | Navigation-only(W-CHAT-001 이동, context 전달) | — |
| Wife | W-CHAT-001 | 조회(대화 이력) | 대화 메시지 | `chat_messages`(MISSING) | `GET /api/v1/chat/messages?date={date}` [제안] | FUC-W-CHAT-001 |
| Wife | W-CHAT-001 | 메시지 전송 | 사용자 입력, AI 응답 | `chat_messages`(MISSING) | `POST /api/v1/chat/messages` [제안] | FUC-W-CHAT-001 |
| Wife | W-CHAT-001 | "이걸로 할게요"(대체 메뉴 수락) | 대체 메뉴 반영 + 수락 이력 | `routine_items.payload`(갱신) + `recommendation_feedback`(MISSING) | `PUT /api/v1/care/routine-items/{itemId}` [제안] | FUC-W-MEAL-003/004 |
| Wife | W-HOUSE-001 | 조회(3분류 표시) | routine_items 중 household 카테고리 | `routine_items`(category=household) | `GET /api/v1/household/today` [기존, STEP 11] | FUC-W-HOUSE-001 |
| Wife | W-HOUSE-001 | 가전 실행 버튼(지금/예약/야간) | ThinQ 실행 명령 | — | Phase 2 — 미제안 | FUC-W-HOUSE-002 |
| Wife | W-HOUSE-001 | 공유 항목 선택 + "남편에게 공유하기" | 요청 이유, 집안일 목록, 보조정보 | `household_requests`/`household_request_items`(MISSING) | `POST /api/v1/family/household-requests` [기존, Stub] | FUC-W-HOUSE-003 |
| Wife | W-HOUSE-001 | 공유완료 팝업 | — | — | Navigation-only(직전 응답 재사용, 별도 API 없음) | FUC-W-HOUSE-003-1 |
| Wife | W-HOUSE-001 | 남편 진행상태 반영 표시(조회) | household_requests.status | `household_requests`(MISSING) | `GET /api/v1/family/household-requests` [기존, Stub] | FUC-W-RECORD-002 |
| Wife | W-HEALTH-001 | 조회(부위/활동 추천) | routine_items 중 health 카테고리 | `routine_items`(category=health) | `GET /api/v1/health/today` [기존, STEP 11] | FUC-W-HEALTH-001 |
| Wife | W-HEALTH-001 | 완료 체크 | routine_items.status/completed_by | `routine_items` | `PUT /api/v1/care/routine-items/{itemId}/execution` [기존, Stub] | FUC-W-HEALTH-002/FUC-W-RECORD-001 |
| Wife | W-SLEEP-001 | 조회(수면 가이드) | routine_items 중 sleep 카테고리 | `routine_items`(category=sleep) | `GET /api/v1/sleep/today` [기존, STEP 11] | FUC-W-SLEEP-001 |
| Wife | W-SLEEP-001 | 환경 설정 적용(바텀시트) | 조명/온도/습도/소리/공기청정기 override | `recommendation_feedback`(kind=sleep_env_override, MISSING) | `PUT /api/v1/care/routine-items/{itemId}/sleep-environment` [제안] | FUC-W-SLEEP-001-1 |
| Wife | W-SLEEP-001 | "수면 루틴 시작하기"(가전 일괄 실행) | ThinQ 실행 명령 | — | Phase 2 — 미제안 | FUC-W-SLEEP-002 |
| Wife | B-CAL-001 | 조회(월/일 상세) | 날짜별 컨디션·실행루틴·가전·분담 | `daily_conditions`+`routine_items`+`daily_reports`(조회조합) | `GET /api/v1/care/calendar/{month}` [기존, Stub] | FUC-B-CAL-001 |
| Wife | W-REPORT-001 | 미리보기("일정 마치기" 직후) | 실행 통계, 최다 부담 부위 | `daily_conditions`+`routine_items`+`posture_events`(조회조합) | `POST /api/v1/care/daily-reports/{date}/preview` [기존, Stub] | FUC-W-REPORT-001 |
| Wife | W-REPORT-001 | "저장하고 마치기"(확정) | 확정 리포트 | `daily_reports`(MISSING) | `POST /api/v1/care/daily-reports/{date}/finalize` [기존, Stub] | FUC-W-REPORT-001 |
| Wife | W-REPORT-001 | "남편에게 공유" | shared_at | `daily_reports`(MISSING) | `POST /api/v1/care/daily-reports/{date}/finalize`(응답에 공유 포함, 별도 제안 없음) | FUC-W-REPORT-001-1 |
| Wife | W-REPORT-001 | 조회(과거 리포트) | 확정 리포트 | `daily_reports`(MISSING) | `GET /api/v1/care/daily-reports/{date}` [기존, Stub] | FUC-W-REPORT-001/002 |
| Wife | B-MOTION-001 | 조회(실시간 상태) | 세션 누적 상태 | 프로세스 메모리(`motion_sessions` MISSING) | `GET /api/v1/movement/live` [기존] | FUC-B-MOTION-001 |
| Wife | B-MOTION-001 | 조회(누적 이벤트/알림) | 임계 이벤트 | `posture_events` | `GET /api/v1/movement/events`, `GET /api/v1/movement/report/daily` [기존] | FUC-B-MOTION-001 |
| Wife | B-MOTION-001 | ON/OFF 토글 | collection_enabled | `motion_consents`(MISSING) | `PUT /api/v1/family/motion/collection` [기존, Stub] | FUC-B-MOTION-001 |
| Wife | B-MOTION-001 | 동의 철회 | consent_granted | `motion_consents`(MISSING) | `DELETE /api/v1/family/motion/consent` [기존, Stub] | NFR-012 |
| Wife | W-CALLBACK-001 | "다시 시도하기" | 루틴 재생성 | `daily_routines`/`routine_items` | `POST /api/v1/routine/today`(재호출) [기존] | FUC-W-CALLBACK-001 |
| Wife | W-MENU-001 | 조회(프로필 요약+연동 상태) | 이름·주차·출산예정일, 남편 연동 상태 | `pregnancy_profiles` + `partner_links`(MISSING) | `GET /api/v1/profile/me` [기존] + `GET /api/v1/account/partner-link` [기존, Stub] | FUC-W-MENU-001 |
| Wife | W-MENU-001 | 메뉴 행 탭(프로필수정/초대/설정/약관) | — | — | Navigation-only | — |
| Wife | W-SETTING-001 | 글자 크기 선택(작게/기본/크게) | — | — | 요구사항은 확정됐으나 기기 로컬 저장·계정 미동기화라 백엔드 API 불필요(`04_1_기능요구사항명세서.md:133`) | FUC-W-SETTING-001 |

## Husband Screen / Data / API Mapping

| Actor | Screen | Action | Data | Source Table | API | FUC |
|---|---|---|---|---|---|---|
| Husband | B-ENTRY-001 | 초대 수락 | 토큰 검증, 계정 연동 | `partner_invitations`/`partner_links`(MISSING) | `POST /api/v1/account/partner-invitations/{token}/accept` [제안, 화면 자체가 TBD] | FUC-H-INVITE-001 |
| Husband | B-CAL-001 | 조회(읽기 전용) | 날짜별 컨디션/실행/가전/분담 | 위 Wife B-CAL-001과 동일 Source | `GET /api/v1/care/calendar/{month}` [기존, Stub — 남편 role 응답 필터링은 미구현] | FUC-B-CAL-001 |
| Husband | H-NOTI-001 | 조회(알림 목록) | 알림 유형/요약/시각/읽음여부 | `notifications`(MISSING) | `GET /api/v1/family/notifications` [기존, Stub] | FUC-H-NOTI-001 |
| Husband | H-NOTI-001 | 읽음 처리 | notifications.read_at | `notifications`(MISSING) | `POST /api/v1/family/notifications/{id}/read` [기존, Stub] | FUC-H-NOTI-001 |
| Husband | H-NOTI-001 | 알림 탭 | — | — | Navigation-only(해당 상세 화면 이동) | — |
| Husband | H-REPORT-001 | 조회(오전 리포트) | 주차·컨디션 요약·예정 활동·가이드 요약(허용 범위만) | `daily_conditions`+`routine_items`(남편 허용 범위로 파생) | `GET /api/v1/family/morning-reports/{date}` [기존, Stub] | FUC-H-REPORT-001 |
| Husband | H-REQUEST-001 | 조회(요청 목록/상세) | 요청 사유, 집안일 목록, 보조정보 | `household_requests`/`household_request_items`(MISSING) | `GET /api/v1/family/household-requests`, `GET /api/v1/family/household-requests/{id}` [기존, Stub] | FUC-H-REQUEST-001 |
| Husband | H-REQUEST-001 | "확인" | status: 요청됨→확인됨 | `household_requests`(MISSING) | `POST /api/v1/family/household-requests/{id}/confirm` [기존, Stub] | FUC-H-REQUEST-002 |
| Husband | H-REQUEST-001 | "완료했어요"+확인팝업 | status: 확인됨→완료됨, routine_items 동기화 | `household_requests`(MISSING) + `routine_items`(완료 동기화) | `POST /api/v1/family/household-requests/{id}/complete` [기존, Stub] | FUC-H-REQUEST-002 |
| Husband | H-REQUEST-002 | 조회(완료 결과 요약) | 완료 처리 상태, 가족 분담 내역 | `household_requests`(MISSING) | `complete` 응답 재사용(별도 GET 미제안) | FUC-H-REQUEST-003 |
| Husband | H-REQUEST-002 | "캘린더로 돌아가기" | — | — | Navigation-only | — |
| Husband | B-MOTION-001 | 조회(읽기 전용) | 누적 시간, 임계값 알림 | `posture_events` | `GET /api/v1/movement/events`, `GET /api/v1/movement/report/daily` [기존 — 남편 role 조회 권한 분기는 미구현] | FUC-B-MOTION-001 |

---

## 신규 제안 API 요약 [제안]

기존에 없어 이번 문서에서 새로 제안한 경로만 모았다(모두 기존 도메인 prefix·네이밍 컨벤션을 따름, 테이블명 미노출):

| API | 근거 화면 | 비고 |
|---|---|---|
| `PUT /api/v1/profile/me/pregnancy-history` | W-PROFILE-003, W-PROFILE-004 | `is_first_pregnancy`, `is_multiple_pregnancy` 한 리소스로 통합 |
| `PUT /api/v1/profile/me/allergies` | W-PROFILE-005 | |
| `PUT /api/v1/profile/me/medical-notes` | W-PROFILE-006 | |
| `GET/POST /api/v1/chat/messages` | W-CHAT-001 | `chat_messages` 테이블 신설 필요(DB_REQUIRED 선행) |
| `PUT /api/v1/care/routine-items/{itemId}` | W-CHAT-001(대체 메뉴 수락) | 기존 `.../execution`과 별도 리소스, `recommendation_feedback` 기록 동반 |
| `PUT /api/v1/care/routine-items/{itemId}/sleep-environment` | W-SLEEP-001 팝업 | `recommendation_feedback`(kind=sleep_env_override) 기록 |
| `POST /api/v1/account/partner-invitations/{token}/accept` | B-ENTRY-001(남편) | FUC-H-INVITE-001 화면 자체가 TBD라 확정 아님 |

## Navigation-only 목록(API 미제안)

W-PROFILE-007의 "완료하고 시작하기"·요약 행 탭, W-INVITE-001의 "나중에", W-HOME-001의 "수정" 탭, W-MEAL-001/002의 카드·재조정 탭, W-HOUSE-001의 공유완료 팝업, W-MENU-001의 메뉴 행 탭, H-NOTI-001의 알림 탭, H-REQUEST-002의 "캘린더로 돌아가기". 공통 이유: 이미 로드된 데이터로 화면만 전환하거나, 직전 API 응답을 그대로 재사용한다.

## Phase 2(ThinQ 가전 실행) 목록(API 미제안)

W-HOUSE-001의 가전 즉시 실행/예약/야간, W-SLEEP-001의 "수면 루틴 시작하기" — `04_1_기능요구사항명세서.md`가 이미 "MVP는 표시까지만"으로 명시했고 ThinQ API 연동 자체가 범위 밖이라 이 문서에서 엔드포인트를 제안하지 않는다.
