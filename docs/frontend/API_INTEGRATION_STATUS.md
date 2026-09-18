# Frontend API Integration Status

- 작성일: 2026-09-18 (STEP 15)
- 기준: `docs/SCREEN_IMPLEMENTATION_MAP.md`(화면별 구현 파일, 기존 Mock 상태 확인), `docs/backend/API_IMPLEMENTATION_MATRIX.md`(Backend API 상태), `docs/backend/API_CONTRACT.md`(Request/Response 계약).
- 목적: 화면별로 "Backend에 연결됐는지, 아직 Mock인지"를 기록하고, Frontend가 DB 구조를 직접 알지 않는 경계(Frontend → API → Service → Repository → DB)가 실제로 지켜지는지 확인한다.
- 이 문서는 Backend 쪽 47개 API 구현(STEP 8~14)과 기존 Frontend 코드(`docs/SCREEN_IMPLEMENTATION_MAP.md`가 이미 "Mock" 상태로 명시)를 대조한 결과다. **기존 UI/디자인은 변경하지 않았다** — 이번 STEP에서 바꾼 코드는 화면 뒤의 데이터 계층(Repository)뿐이다.

## 아키텍처 경계 (이번 STEP에서 확립)

```
Widget/Screen (UI, 변경 없음)
    ↓
Controller/Store (상태 관리, 변경 없음 — 단 TodayCareStore는 Repository를 주입받도록 확장)
    ↓
Repository 인터페이스 (신규 — Mock/Api 구현이 이 하나를 공유)
    ↓            ↘
MockXxxRepository   ApiXxxRepository
(메모리)              ↓
                  ApiClient (lib/core/network/api_client.dart, 신규 Service 계층)
                       ↓
                  Backend REST API (/api/v1/**)
                       ↓
                  Service → Repository → DB (Backend 쪽, 이미 STEP 8~14에서 구현)
```

- `lib/core/network/api_client.dart`: Frontend에서 Backend를 호출하는 유일한 통로. `AppConfig.backendUrl` + Supabase Auth 세션 토큰(`Authorization: Bearer`)만 사용하고, Supabase Table을 직접 조회하지 않는다. **아내/남편 화면 DB 스키마 문서는 여기서도 Backend 설계 참고자료로만 썼고, Frontend가 Supabase Table명을 아는 코드는 어디에도 없다.**
- `lib/features/condition/data/condition_repository.dart`(+`mock_`/`api_` 구현체): Mock과 API 구현이 동일 인터페이스를 쓰는 예시를 실제로 만들고 테스트로 증명했다(`test/features/condition/condition_repository_test.dart`). 다른 화면에 같은 패턴을 넓히는 작업은 화면마다 로딩·오류 UI가 필요해 이번 STEP에서는 이 예시 하나만 구현하고, 나머지는 상태만 기록한다(아래 표).
- `TodayCareStore`의 기본값은 여전히 `MockConditionRepository`다 — API 구현으로 기본값을 바꾸는 것은 화면에 로딩/오류 상태를 추가하는 별도 작업이라 **UI를 바꾸지 않는다는 이번 STEP 원칙**에 따라 하지 않았다.

## 상태 정의

- **CONNECTED**: 화면이 실제 Backend API를 호출한다.
- **PATTERN_READY**: Repository 인터페이스 + Mock/Api 구현이 모두 있고 테스트로 상호 교체 가능함을 확인했지만, 화면에 연결된 기본값은 아직 Mock이다(로딩/오류 UI 추가가 남은 작업).
- **MOCK_ONLY**: Repository 인터페이스 없이 화면 전용 메모리/localStorage Store만 있다(`docs/SCREEN_IMPLEMENTATION_MAP.md`가 이미 이렇게 명시한 기존 상태, 이번 STEP에서 바꾸지 않음).
- **NOT_APPLICABLE**: 저장할 데이터가 없는 화면(Placeholder, Phase 2, 순수 표시)이라 연결 대상이 아니다.

Backend API 상태(`implemented`/`stub`/`planned`)는 `docs/backend/API_IMPLEMENTATION_MATRIX.md`를 그대로 인용한다.

---

## Wife 화면

| Screen ID | Route | Frontend 연결 상태 | 대응 Backend API | Backend API 상태 | 비고 |
|---|---|---|---|---|---|
| B-ENTRY-001 | `/entry` | MOCK_ONLY | `GET /account/bootstrap` | implemented | Bootstrap 판정을 Frontend가 로컬로 흉내 냄 |
| W-PROFILE-001 | `/onboarding/profile` step1 | MOCK_ONLY | `PUT /profile/me/due-date` | implemented | `ProfileDraft` + localStorage, 서버 미호출 |
| W-PROFILE-002 | 동일 step2 | MOCK_ONLY | `PUT /profile/me/body` | implemented | |
| W-PROFILE-003 | 동일 step3 | MOCK_ONLY | `PUT /profile/me/pregnancy-history` | implemented | |
| W-PROFILE-004 | 동일 step4 | MOCK_ONLY | `PUT /profile/me/pregnancy-count` | implemented | |
| W-PROFILE-005 | 동일 step5 | MOCK_ONLY | `PUT /profile/me/allergies` | implemented | |
| W-PROFILE-006 | 동일 step6 | MOCK_ONLY | `PUT /profile/me/medical-notes` | implemented | |
| W-PROFILE-007 | 동일 Summary | MOCK_ONLY | `GET /profile/me` | implemented | 6단계 전부 Backend는 이미 실연결 완료 상태 — Frontend 연결이 가장 먼저 볼 만한 후보 |
| W-INVITE-001 | `/onboarding/invite`, `/wife/invite` | MOCK_ONLY | `POST /account/partner-invitations` | implemented | 링크 생성은 Mock, 실제 발급 API는 이미 있음(72시간·1회성 DB 제약 포함) |
| W-MENU-001/001-1 | `/wife/menu` | MOCK_ONLY | `GET /profile/me` + `GET /account/partner-link` | implemented | 연동 상태는 `partner_connection_store.dart`(로컬)로 흉내 냄 |
| W-HOME-001/001-1 | `/wife/home` | MOCK_ONLY | `GET /routine/today` + `GET /care/conditions/{date}` + `POST /care/daily-reports/{date}/preview` | implemented | 4종 가이드·컨디션 요약 모두 Mock |
| W-COND-001 | `/wife/condition` | **PATTERN_READY**(이번 STEP) | `GET/PUT /care/conditions/{date}` | implemented | `ConditionRepository` 인터페이스 신규 — 기본값은 여전히 Mock |
| W-TASK-001 | `/wife/activity` | MOCK_ONLY | `PUT /care/conditions/{date}/activities` + `POST /routine/today` | implemented | |
| W-CALLBACK-001 | Home 내부 상태 | MOCK_ONLY | `POST /routine/today`(재시도) | implemented | |
| W-MEAL-001/002 | `/wife/meal` | MOCK_ONLY | `GET /meals/today` | implemented | Query Layer(STEP 11)가 이미 준비돼 있음 |
| W-MEAL-003, W-CHAT-001 | `/wife/chat` | MOCK_ONLY | `GET/POST /chat/messages` | **stub** | Backend도 아직 고정 안내 문구만 반환 — 연결해도 실제 AI 응답은 없음 |
| W-HOUSE-001/001-1/001-2 | `/wife/household` | MOCK_ONLY | `GET /household/today`(조회) + `POST/GET /family/household-requests`, `.../confirm`, `.../complete` | implemented(요청·상태전이 STEP 17) | |
| W-HEALTH-001 | `/wife/health` | MOCK_ONLY | `GET /health/today` + `PUT /care/routine-items/{id}/execution` | implemented | |
| W-SLEEP-001~001-5 | `/wife/sleep` | MOCK_ONLY | `GET /sleep/today` + `PUT /care/routine-items/{id}/sleep-environment` | 조회 implemented, override **stub** | |
| W-REPORT-001/001-1 | `/wife/report/:date` | MOCK_ONLY | `POST .../preview`, `.../finalize`, `GET .../daily-reports/{date}` | implemented | 날짜별 Mock 조회 → 실제 API로 교체 가능(Backend는 Record+Condition+Movement에서 파생, STEP 12) |
| B-CAL-001(Wife) | `/wife/calendar` | MOCK_ONLY | `GET /care/calendar/{month}` | implemented | |
| B-MOTION-001(Wife) | `/wife/movement` | MOCK_ONLY(Phase 2 Mock으로 명시) | `WS /movement/live/stream`, `GET /live,/events,/report/daily` + `GET/PUT/DELETE /family/motion/*` | **implemented(둘 다)** | Backend는 실제 카메라 연동까지 동작하지만 Frontend는 여전히 Mock — 격차가 가장 큰 화면. STEP 18: WS 연결 시 동의 검사 추가 — 동의 없음/수집 OFF면 close code **4003**, origin/토큰 문제는 1008. 프론트는 4003에서 동의 화면으로 유도하고, 동의 철회 버튼에서 열린 WS를 끊어야 함(NFR-012) |
| W-SETTING-001 | `/wife/settings` | NOT_APPLICABLE | 없음 | — | 상세 항목 자체가 미확정(Phase 2), 연결 대상 없음 |

## Husband 화면

| Screen ID | Route | Frontend 연결 상태 | 대응 Backend API | Backend API 상태 | 비고 |
|---|---|---|---|---|---|
| H-INVITE-001(`/partner/join`) | `/partner/join?token=...` | NOT_APPLICABLE(의도적 비활성) | `POST /account/partner-invitations/{token}/accept` | implemented | Backend는 준비됐지만 Frontend는 "개발중" 안내만 표시(SCREEN_IMPLEMENTATION_MAP.md에 이미 의도적으로 비활성화라고 명시) — 화면·인증 복귀 계약 자체가 Backend 쪽에서도 TBD |
| B-CAL-001(Partner) | `/partner/calendar` | MOCK_ONLY | `GET /care/calendar/{month}` | implemented(STEP 17: 남편 토큰으로 호출하면 연동된 아내 캘린더 반환) | |
| B-MOTION-001(Partner) | `/partner/movement` | MOCK_ONLY(Phase 2 Mock) | `GET /movement/events,/report/daily` | implemented(STEP 18: 남편 토큰으로 호출하면 연동된 아내 데이터 반환) | `ProductMovementScreen`의 Mock 데이터를 이 두 API로 교체하면 됨. 참고: `ROUTE_MAP.md`는 PHASE_2, `docs/requirements/01_MVP.md`는 Phase 1 — 프론트/기획이 범위 확인 필요 |
| H-REPORT-001 | `/partner/report/:date` | MOCK_ONLY | `GET /family/morning-reports/{date}` | implemented(STEP 12, family authorization+projection) | Backend는 이미 원본 비노출·정성 요약까지 구현됨 — 연결 우선순위 높음 |
| H-NOTI-001 | `/partner/notifications` | MOCK_ONLY | `GET /family/notifications`, `POST .../read` | implemented(STEP 17) | 알림 3종 전부 Backend에서 발송됨(가사 요청/오전 리포트/루틴 변경) |
| H-REQUEST-001/001-1/001-2, H-REQUEST-002 | `/partner/requests/:requestId` | MOCK_ONLY | `GET .../household-requests/{id}`, `.../confirm`, `.../complete` | implemented(STEP 17) | |

---

## 우선 연결 후보 (Backend가 이미 `implemented`인데 Frontend는 아직 `MOCK_ONLY`인 화면)

Backend 쪽 검증(자동 테스트)이 끝난 상태라 Frontend Repository만 추가하면 바로 연결 가능한 화면들이다. 우선순위는 화면 복잡도(로딩/오류 상태 UI가 얼마나 필요한지)가 아니라 **Backend 준비도** 기준으로만 나열한다:

1. W-PROFILE-001~007(6단계 전부 실연결 완료, Backend 쪽은 STEP 8/10에서 이미 회귀 테스트까지 마침)
2. W-COND-001(이번 STEP에서 Repository까지 만들어 둠 — 남은 건 기본값을 Api로 바꾸고 로딩/오류 UI를 추가하는 것뿐)
3. W-MEAL-001/002, W-HOUSE-001(조회만), W-HEALTH-001, W-SLEEP-001(조회만) — Guide Query 4종(STEP 11)
4. W-INVITE-001, W-MENU-001 — 파트너 연동(STEP 13)
5. H-REPORT-001 — 남편 오전 리포트(STEP 12)
6. B-CAL-001(Wife/Partner) — 캘린더(STEP 12)
7. B-MOTION-001의 동의/수집 설정(`GET/PUT/DELETE /family/motion/*`, STEP 14) — 단, 실시간 스트림 자체는 이미 Backend가 실동작하므로 Frontend Mock을 걷어내는 효과가 가장 큼

다음 후보(Backend가 `stub`이라 Frontend 연결을 먼저 해도 실제 저장은 안 됨): W-CHAT-001/003만 남음. H-NOTI-001, H-REQUEST-001/002, W-HOUSE-001 요청 전송·상태 전이는 STEP 17에서 Backend가 implemented로 바뀌어 연결 가능하다. 특히 W-TASK-001의 'AI 하루 루틴 만들기'(`planned_activity_controller.dart`, 아직 Mock)를 `POST /routine/today`에 연결하면 남편 알림(오전 리포트/루틴 변경)이 실제로 발송된다.

## 이번 STEP에서 만든 코드

- `lib/core/network/api_client.dart` — Service 계층(신규)
- `lib/features/condition/data/condition_repository.dart`, `mock_condition_repository.dart`, `api_condition_repository.dart` — Repository 인터페이스 예시(신규)
- `lib/features/condition/data/today_care_store.dart` — Repository를 주입받도록 확장(기본값은 Mock 유지, 기존 동작 100% 보존)
- `test/features/condition/condition_repository_test.dart` — Mock/Api 상호 교체 가능성 증명 테스트(신규)

기존 화면 Widget·디자인 파일은 하나도 수정하지 않았다(`git status`로 확인: `lib/features/condition/data/today_care_store.dart` 1개만 수정, 나머지는 전부 신규 파일).
