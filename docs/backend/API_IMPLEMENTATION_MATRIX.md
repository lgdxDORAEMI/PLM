# API Implementation Matrix

- 작성일: 2026-09-17 (STEP 5 초안, STEP 8·STEP 9·STEP 11·STEP 17(2026-09-18)에서 구현 결과로 갱신)
- 목적: `API_CONTRACT.md`의 47개 API를 한 화면에서 스캔할 수 있는 요약 매트릭스. 상세 Request/Response/Source Data는 `API_CONTRACT.md` 참고.
- 상태 정의는 `API_CONTRACT.md`와 동일: **implemented / partial / stub / planned**.
- STEP 8에서 8개 planned API를 실제로 구현했다. 프로필 3~4단계(`pregnancy-history`/`pregnancy-count`)는 화면이 실제로는 2개(003, 004)라 STEP 5의 결합안을 깨고 API도 2개로 나눴다 — 그래서 전체 개수가 42→43이 됐다.
- STEP 9에서 Condition 3개(`GET/PUT /care/conditions/{date}`, `.../activities`)를 stub→implemented로 전환했다.
- STEP 11에서 Guide Query 4개(`/meals/today`, `/household/today`, `/health/today`, `/sleep/today`)를 신규 구현했다(43→47).
- STEP 12에서 Record(`.../execution`), Report(`.../preview`·`.../finalize`·`GET .../daily-reports`), Calendar(`GET .../calendar/{month}`), 남편 오전 리포트(`GET /family/morning-reports/{date}`) 6개를 stub→implemented로 전환했다.
- STEP 13에서 파트너 연동(`bootstrap`, `partner-link`, `partner-invitations` 발급·수락) 4개를 stub→implemented로 전환했다 — `partner_links`/`partner_invitations` 실 연결, 초대 1회성·72시간 만료·중복 연동 거절(409)까지 포함.
- STEP 14에서 모션 동의(`family/motion/privacy`·`/consent` PUT·DELETE·`/collection`) 4개를 stub→implemented로 전환했다 — `motion_consents` 실 연결. `posture_events`/`posture_calibration_profiles`(Protected)는 이미 `EventStore` Protocol(+`InMemoryEventStore`+`SupabaseEventStore`) 경계를 갖추고 있어 신규 Repository를 추가하지 않았다.
- STEP 19(2026-09-18)에서 routine-item 피드백 2개(`PUT /care/routine-items/{id}` 메뉴 수락/거절/재요청, `.../sleep-environment` 수면 override)를 stub→implemented로 전환했다 — `recommendation_feedback`에 이력만 기록하고 `routine_items`(Protected)는 소유자 확인·응답용으로 읽기만 한다.
- STEP 17(2026-09-18)에서 Household 5개(`family/household-requests` 생성·목록·단건·confirm·complete)와 Notification 2개(`family/notifications` 목록·read)를 stub→implemented로 전환했다 — `household_requests`/`household_request_items`/`notifications` 실 연결. 같은 STEP에서 `GET /care/calendar/{month}`에 남편 role 분기(`partner_links`로 연동된 아내 캘린더 읽기 전용 조회)를 추가하고, Daily 리포트의 `family` 집계를 `household_requests` 실조회(누적 funnel)로 교체했으며, `POST /routine/today` 성공 시 남편 알림(첫 생성 `morning_report`, 재생성 `condition_changed`)을 발송하도록 연결했다(FUC-W-COND-002/003).

## 전체 매트릭스

| Domain | Method | Path | Actor | Screen(s) | FUC | Status |
|---|---|---|---|---|---|---|
| Profile | GET | `/api/v1/profile/me` | Wife | W-PROFILE-001/007, W-HOME-001, W-MENU-001 | FUC-W-PROFILE-001/007 | implemented |
| Profile | PUT | `/api/v1/profile/me/due-date` | Wife | W-PROFILE-001 | FUC-W-PROFILE-001 | implemented |
| Profile | PUT | `/api/v1/profile/me/body` | Wife | W-PROFILE-002 | FUC-W-PROFILE-002 | implemented |
| Profile | PUT | `/api/v1/profile/me/pregnancy-history` | Wife | W-PROFILE-003 | FUC-W-PROFILE-003 | implemented |
| Profile | PUT | `/api/v1/profile/me/pregnancy-count` | Wife | W-PROFILE-004 | FUC-W-PROFILE-004 | implemented |
| Profile | PUT | `/api/v1/profile/me/allergies` | Wife | W-PROFILE-005 | FUC-W-PROFILE-005 | implemented |
| Profile | PUT | `/api/v1/profile/me/medical-notes` | Wife | W-PROFILE-006 | FUC-W-PROFILE-006 | implemented |
| Account | GET | `/api/v1/account/bootstrap` | Both | B-ENTRY-001 | FUC-B-ENTRY-001 | implemented |
| Account | GET | `/api/v1/account/partner-link` | Wife | W-MENU-001, W-INVITE-001 | FUC-W-MENU-001 | implemented |
| Account | POST | `/api/v1/account/partner-invitations` | Wife | W-INVITE-001 | FUC-W-INVITE-001 | implemented |
| Account | POST | `/api/v1/account/partner-invitations/{token}/accept` | Husband | B-ENTRY-001(남편) | FUC-H-INVITE-001 | implemented |
| Routine | GET | `/api/v1/routine/today` | Wife | W-HOME-001, W-MEAL-001/002, W-HOUSE-001, W-HEALTH-001, W-SLEEP-001 | FUC-W-HOME-001 외 다수 | implemented |
| Routine | POST | `/api/v1/routine/today` | Wife | W-TASK-001, W-CALLBACK-001 | FUC-W-ROUTINE-001/003 | implemented |
| Care | GET | `/api/v1/care/conditions/{target_date}` | Wife | W-COND-001 | FUC-W-COND-001 | implemented |
| Care | PUT | `/api/v1/care/conditions/{target_date}` | Wife | W-COND-001 | FUC-W-COND-001 | implemented |
| Care | PUT | `/api/v1/care/conditions/{target_date}/activities` | Wife | W-TASK-001 | FUC-W-TASK-001 | implemented |
| Care | PUT | `/api/v1/care/routine-items/{item_id}/execution` | Wife | W-HEALTH-001, W-MEAL/SLEEP(공통 컴포넌트) | FUC-W-RECORD-001, FUC-W-HEALTH-002 | implemented |
| Care | PUT | `/api/v1/care/routine-items/{item_id}` | Wife | W-CHAT-001(메뉴 수락) | FUC-W-MEAL-003/004 | implemented |
| Care | PUT | `/api/v1/care/routine-items/{item_id}/sleep-environment` | Wife | W-SLEEP-001(팝업) | FUC-W-SLEEP-001-1 | implemented |
| Care | POST | `/api/v1/care/daily-reports/{target_date}/preview` | Wife | W-HOME-001, W-REPORT-001 | FUC-W-HOME-002, FUC-W-REPORT-001 | implemented |
| Care | POST | `/api/v1/care/daily-reports/{target_date}/finalize` | Wife | W-REPORT-001 | FUC-W-REPORT-001/001-1 | implemented |
| Care | GET | `/api/v1/care/daily-reports/{target_date}` | Wife | W-REPORT-001, B-CAL-001 | FUC-W-REPORT-001/002 | implemented |
| Care | GET | `/api/v1/care/calendar/{month}` | Wife, Husband | B-CAL-001 | FUC-B-CAL-001 | implemented |
| Household | POST | `/api/v1/family/household-requests` | Wife | W-HOUSE-001 | FUC-W-HOUSE-003 | implemented |
| Household | GET | `/api/v1/family/household-requests` | Wife, Husband | W-HOUSE-001, H-REQUEST-001 | FUC-W-RECORD-002, FUC-H-REQUEST-001 | implemented |
| Household | GET | `/api/v1/family/household-requests/{request_id}` | Husband | H-REQUEST-001 | FUC-H-REQUEST-001 | implemented |
| Household | POST | `/api/v1/family/household-requests/{request_id}/confirm` | Husband | H-REQUEST-001 | FUC-H-REQUEST-002 | implemented |
| Household | POST | `/api/v1/family/household-requests/{request_id}/complete` | Husband | H-REQUEST-001 | FUC-H-REQUEST-002/003 | implemented |
| Report | GET | `/api/v1/family/morning-reports/{target_date}` | Husband | H-REPORT-001 | FUC-H-REPORT-001 | implemented |
| Notification | GET | `/api/v1/family/notifications` | Husband | H-NOTI-001 | FUC-H-NOTI-001 | implemented |
| Notification | POST | `/api/v1/family/notifications/{notification_id}/read` | Husband | H-NOTI-001 | FUC-H-NOTI-001 | implemented |
| Chat | GET | `/api/v1/chat/messages` | Wife | W-CHAT-001 | FUC-W-CHAT-001 | partial |
| Chat | POST | `/api/v1/chat/messages` | Wife | W-CHAT-001 | FUC-W-CHAT-001 | partial |
| Movement | WS | `/api/v1/movement/live/stream` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/live` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/events` | Wife, Husband | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/report/daily` | Wife, Husband | B-MOTION-001, W-REPORT-002 | FUC-B-MOTION-001 | implemented |
| Guide | GET | `/api/v1/meals/today` | Wife | W-MEAL-001/002 | FUC-W-MEAL-001/002 | implemented |
| Guide | GET | `/api/v1/household/today` | Wife | W-HOUSE-001 | FUC-W-HOUSE-001 | implemented |
| Guide | GET | `/api/v1/health/today` | Wife | W-HEALTH-001 | FUC-W-HEALTH-001 | implemented |
| Guide | GET | `/api/v1/sleep/today` | Wife | W-SLEEP-001 | FUC-W-SLEEP-001 | implemented |
| Movement | GET | `/api/v1/family/motion/privacy` | Wife | B-MOTION-001 | NFR-012 | implemented |
| Movement | PUT | `/api/v1/family/motion/consent` | Wife | B-MOTION-001 | NFR-012 | implemented |
| Movement | DELETE | `/api/v1/family/motion/consent` | Wife | B-MOTION-001 | NFR-012 | implemented |
| Movement | PUT | `/api/v1/family/motion/collection` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | implemented |

## 상태별 집계

| Status | 개수 | 비율 |
|---|---|---|
| implemented | 43 | 96% |
| partial | 2 | 4% |
| stub | 0 | 0% |
| planned | 0 | 0% |
| **합계** | **45** | 100% |

## 도메인별 집계

| Domain | implemented | partial | planned | 합계 |
|---|---|---|---|---|
| Profile | 7 | 0 | 0 | 7 |
| Account(bootstrap/invite/link) | 4 | 0 | 0 | 4 |
| Routine(Routine AI 소유) | 2 | 0 | 0 | 2 |
| Care/Condition/Record/Report/Calendar | 10 | 0 | 0 | 10 |
| Guide(Meal/Household/Health/Sleep 조회, STEP 11) | 4 | 0 | 0 | 4 |
| Household | 5 | 0 | 0 | 5 |
| Report(남편 공유, STEP 12) | 1 | 0 | 0 | 1 |
| Notification | 2 | 0 | 0 | 2 |
| Chat | 0 | 2(대화 이력 저장은 실연결, 실제 AI 응답은 placeholder) | 0 | 2 |
| Movement(`movement.py` Protected 4 + `family.motion.*` STEP 14 실연결 4) | 8 | 0 | 0 | 8 |
| **합계** | **43** | **2** | **0** | **45** |

## Protected 모듈 표시

`movement`(4개, WS/live/events/report·daily) = **4개 API가 Protected**다(2026-09-18 개정: `routine` 2개는 Routine AI 담당 소유로 이관). 이 문서와 `API_CONTRACT.md`는 이 6개의 계약을 그대로 기록만 했고 변경을 제안하지 않는다. `family.motion.*` 4개(privacy/consent/collection)는 Protected가 아니지만 Protected `movement.py`의 WS 연결 게이트와 아직 연동되지 않은 상태로 남아 있다(`DOMAIN_OWNERSHIP.md` 기존 TBD).

## 우선 구현 후보(stub → implemented 전환)

STEP 9(Condition)·STEP 12(Record/Report/Calendar/남편 오전 리포트)·STEP 13(파트너 연동)·STEP 14(모션 동의)·STEP 17(Household/Notification)에서 전환을 마쳤다. STEP 7 migration 9건(`supabase/migrations/20260917010000`~`010800`)은 STEP 17 검증 시 실제 프로젝트에 미적용 상태였음을 확인해 수동 적용했다 — `backend/README.md` "Supabase 준비" 참고.

**2026-09-20**: `GET/PUT /account/profile`(6단계 일괄 Stub)은 `birth_date`를 `/profile/me/body`(STEP 8 계약)에 통합하고 삭제했다 — Frontend가 호출하지 않는 죽은 계약이었다. `GET/POST /chat/messages`는 대화 이력 저장(`chat_messages`)만 Supabase에 실연결했다(stub → partial) — 실제 AI 응답 생성은 NFR-027(보관 정책) 확정 전이라 여전히 고정 안내 문구를 반환한다.
