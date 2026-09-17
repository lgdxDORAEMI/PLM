# API Implementation Matrix

- 작성일: 2026-09-17 (STEP 5)
- 목적: `API_CONTRACT.md`의 42개 API를 한 화면에서 스캔할 수 있는 요약 매트릭스. 상세 Request/Response/Source Data는 `API_CONTRACT.md` 참고.
- 상태 정의는 `API_CONTRACT.md`와 동일: **implemented / partial / stub / planned**.

## 전체 매트릭스

| Domain | Method | Path | Actor | Screen(s) | FUC | Status |
|---|---|---|---|---|---|---|
| Profile | GET | `/api/v1/profile/me` | Wife | W-PROFILE-001/007, W-HOME-001, W-MENU-001 | FUC-W-PROFILE-001/007 | implemented |
| Profile | PUT | `/api/v1/profile/me/due-date` | Wife | W-PROFILE-001 | FUC-W-PROFILE-001 | implemented |
| Profile | PUT | `/api/v1/profile/me/body` | Wife | W-PROFILE-002 | FUC-W-PROFILE-002 | implemented |
| Profile | PUT | `/api/v1/profile/me/pregnancy-history` | Wife | W-PROFILE-003/004 | FUC-W-PROFILE-003/004 | planned |
| Profile | PUT | `/api/v1/profile/me/allergies` | Wife | W-PROFILE-005 | FUC-W-PROFILE-005 | planned |
| Profile | PUT | `/api/v1/profile/me/medical-notes` | Wife | W-PROFILE-006 | FUC-W-PROFILE-006 | planned |
| Account | GET | `/api/v1/account/bootstrap` | Both | B-ENTRY-001 | FUC-B-ENTRY-001 | stub |
| Account | GET | `/api/v1/account/partner-link` | Wife | W-MENU-001, W-INVITE-001 | FUC-W-MENU-001 | stub |
| Account | POST | `/api/v1/account/partner-invitations` | Wife | W-INVITE-001 | FUC-W-INVITE-001 | stub |
| Account | POST | `/api/v1/account/partner-invitations/{token}/accept` | Husband | B-ENTRY-001(남편) | FUC-H-INVITE-001 | planned |
| Account | GET/PUT | `/api/v1/account/profile` | Wife | W-PROFILE-007/008 | FUC-W-PROFILE-007/008 | stub |
| Routine | GET | `/api/v1/routine/today` | Wife | W-HOME-001, W-MEAL-001/002, W-HOUSE-001, W-HEALTH-001, W-SLEEP-001 | FUC-W-HOME-001 외 다수 | implemented |
| Routine | POST | `/api/v1/routine/today` | Wife | W-TASK-001, W-CALLBACK-001 | FUC-W-ROUTINE-001/003 | implemented |
| Care | GET | `/api/v1/care/conditions/{target_date}` | Wife | W-COND-001 | FUC-W-COND-001 | stub |
| Care | PUT | `/api/v1/care/conditions/{target_date}` | Wife | W-COND-001 | FUC-W-COND-001 | stub |
| Care | PUT | `/api/v1/care/conditions/{target_date}/activities` | Wife | W-TASK-001 | FUC-W-TASK-001 | stub |
| Care | PUT | `/api/v1/care/routine-items/{item_id}/execution` | Wife | W-HEALTH-001, W-MEAL/SLEEP(공통 컴포넌트) | FUC-W-RECORD-001, FUC-W-HEALTH-002 | stub |
| Care | PUT | `/api/v1/care/routine-items/{item_id}` | Wife | W-CHAT-001(메뉴 수락) | FUC-W-MEAL-003/004 | planned |
| Care | PUT | `/api/v1/care/routine-items/{item_id}/sleep-environment` | Wife | W-SLEEP-001(팝업) | FUC-W-SLEEP-001-1 | planned |
| Care | POST | `/api/v1/care/daily-reports/{target_date}/preview` | Wife | W-HOME-001, W-REPORT-001 | FUC-W-HOME-002, FUC-W-REPORT-001 | stub |
| Care | POST | `/api/v1/care/daily-reports/{target_date}/finalize` | Wife | W-REPORT-001 | FUC-W-REPORT-001/001-1 | stub |
| Care | GET | `/api/v1/care/daily-reports/{target_date}` | Wife | W-REPORT-001, B-CAL-001 | FUC-W-REPORT-001/002 | stub |
| Care | GET | `/api/v1/care/calendar/{month}` | Wife, Husband | B-CAL-001 | FUC-B-CAL-001 | stub |
| Household | POST | `/api/v1/family/household-requests` | Wife | W-HOUSE-001 | FUC-W-HOUSE-003 | stub |
| Household | GET | `/api/v1/family/household-requests` | Wife, Husband | W-HOUSE-001, H-REQUEST-001 | FUC-W-RECORD-002, FUC-H-REQUEST-001 | stub |
| Household | GET | `/api/v1/family/household-requests/{request_id}` | Husband | H-REQUEST-001 | FUC-H-REQUEST-001 | stub |
| Household | POST | `/api/v1/family/household-requests/{request_id}/confirm` | Husband | H-REQUEST-001 | FUC-H-REQUEST-002 | stub |
| Household | POST | `/api/v1/family/household-requests/{request_id}/complete` | Husband | H-REQUEST-001 | FUC-H-REQUEST-002/003 | stub |
| Report | GET | `/api/v1/family/morning-reports/{target_date}` | Husband | H-REPORT-001 | FUC-H-REPORT-001 | stub |
| Notification | GET | `/api/v1/family/notifications` | Husband | H-NOTI-001 | FUC-H-NOTI-001 | stub |
| Notification | POST | `/api/v1/family/notifications/{notification_id}/read` | Husband | H-NOTI-001 | FUC-H-NOTI-001 | stub |
| Chat | GET | `/api/v1/chat/messages` | Wife | W-CHAT-001 | FUC-W-CHAT-001 | planned |
| Chat | POST | `/api/v1/chat/messages` | Wife | W-CHAT-001 | FUC-W-CHAT-001 | planned |
| Movement | WS | `/api/v1/movement/live/stream` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/live` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/events` | Wife, Husband | B-MOTION-001 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/movement/report/daily` | Wife, Husband | B-MOTION-001, W-REPORT-002 | FUC-B-MOTION-001 | implemented |
| Movement | GET | `/api/v1/family/motion/privacy` | Wife | B-MOTION-001 | NFR-012 | stub |
| Movement | PUT | `/api/v1/family/motion/consent` | Wife | B-MOTION-001 | NFR-012 | stub |
| Movement | DELETE | `/api/v1/family/motion/consent` | Wife | B-MOTION-001 | NFR-012 | stub |
| Movement | PUT | `/api/v1/family/motion/collection` | Wife | B-MOTION-001 | FUC-B-MOTION-001 | stub |

## 상태별 집계

| Status | 개수 | 비율 |
|---|---|---|
| implemented | 9 | 21% |
| partial | 0 | 0% |
| stub | 25 | 60% |
| planned | 8 | 19% |
| **합계** | **42** | 100% |

## 도메인별 집계

| Domain | implemented | stub | planned | 합계 |
|---|---|---|---|---|
| Profile | 3 | 1(`GET/PUT /account/profile`) | 3 | 7 |
| Account(bootstrap/invite/link) | 0 | 3 | 1 | 4 |
| Routine(Protected) | 2 | 0 | 0 | 2 |
| Care/Condition | 0 | 7 | 2 | 9 |
| Household | 0 | 5 | 0 | 5 |
| Report(남편 공유) | 0 | 1 | 0 | 1 |
| Notification | 0 | 2 | 0 | 2 |
| Chat | 0 | 0 | 2 | 2 |
| Movement(`movement.py` Protected 4 + `family.motion.*` Stub 4) | 4 | 4 | 0 | 8 |
| **합계** | **9** | **25** | **8** | **42** |

## Protected 모듈 표시

`routine`(2개) + `movement`(4개, WS/live/events/report·daily) = **6개 API가 Protected**다. 이 문서와 `API_CONTRACT.md`는 이 6개의 계약을 그대로 기록만 했고 변경을 제안하지 않는다. `family.motion.*` 4개(privacy/consent/collection)는 Protected가 아니지만 Protected `movement.py`의 WS 연결 게이트와 아직 연동되지 않은 상태로 남아 있다(`DOMAIN_OWNERSHIP.md` 기존 TBD).

## 우선 구현 후보(stub → implemented 전환)

`TARGET_DB_SCHEMA.md`의 KEEP 테이블(`daily_conditions`)이 이미 존재하므로, 아래는 **신규 migration 없이 Repository만 Supabase adapter로 교체하면 되는** stub API다 — 가장 빠르게 상태를 바꿀 수 있는 후보:

- `GET/PUT /api/v1/care/conditions/{target_date}`
- `PUT /api/v1/care/conditions/{target_date}/activities`
- `PUT /api/v1/care/routine-items/{item_id}/execution`(`routine_items`도 이미 존재)

나머지 stub 21개는 `TARGET_DB_SCHEMA.md`의 NEW 테이블(신규 migration) 선행이 필요하다.
