# Frontend API Integration Status

- 갱신일: 2026-09-20
- 기준: Supabase 설정이 있으면 API 구현을 사용한다. 설정이 없는 실행 화면은 Mock 값 대신 `연동이필요합니다` 빈 상태를 표시한다. 테스트에서 명시한 경우에만 Mock 화면 값을 표시한다.
- 공통 경로: `Screen → Controller/Store → Repository/Service → ApiClient → Backend`
- Frontend Feature 코드는 Supabase Table 또는 RPC를 직접 호출하지 않는다.

## 실제 API 연결

| Feature | Frontend 상태 | Backend API |
|---|---|---|
| 앱 진입 분기 | CONNECTED | `GET /api/v1/account/bootstrap` |
| 프로필 설정(생년월일 포함) | CONNECTED | `GET /api/v1/profile/me`, `PUT /api/v1/profile/me/*` (2026-09-20: `birth_date` 실연결, 안 쓰이던 `/account/profile` 제거) |
| 배우자 초대 발급 | CONNECTED | `POST /api/v1/account/partner-invitations` |
| 배우자 연결 상태 | CONNECTED | `GET /api/v1/account/partner-link` |
| 오늘 컨디션·예정 활동 | CONNECTED | `GET/PUT /api/v1/care/conditions/{date}`, `PUT .../activities` |
| 오늘 루틴·재생성 | CONNECTED | `GET/POST /api/v1/routine/today` |
| 식사 가이드 조회 | CONNECTED | `GET /api/v1/meals/today` |
| 가사 가이드 조회 | CONNECTED | `GET /api/v1/household/today` |
| 가사 요청 생성·목록·상세·확인·완료 | CONNECTED | `/api/v1/family/household-requests/**` |
| 건강 가이드 조회 | CONNECTED | `GET /api/v1/health/today` |
| 수면 가이드 조회 | CONNECTED | `GET /api/v1/sleep/today` |
| Daily 리포트·캘린더 | CONNECTED | `/api/v1/care/daily-reports/**`, `GET /api/v1/care/calendar/{month}` |
| 남편 오전 리포트 | CONNECTED | `GET /api/v1/family/morning-reports/{target_date}` |
| 남편 알림 목록·읽음 처리 | CONNECTED | `GET /api/v1/family/notifications`, `POST .../{notification_id}/read` |
| Movement 제품 화면 이벤트·일일 집계 | CONNECTED | `GET /api/v1/movement/events`, `GET /api/v1/movement/report/daily` |
| Movement 동의·수집 상태 조회 | CONNECTED | `GET /api/v1/family/motion/privacy` |
| Movement 카메라 판정 화면 | CONNECTED | `WS /api/v1/movement/live/stream` |

가사 완료 결과 화면은 로컬 Store에만 의존하지 않고 요청 상세 API를 다시 조회한다. 남편 Movement 화면은 권한 범위에 맞춰 이벤트와 일일 집계만 조회하며, 아내 화면에서만 동의·수집 상태를 함께 조회한다.

## Mock 유지

Mock Service와 Store는 Widget 테스트용으로 유지한다. API 미설정 화면에는 Mock 응답을 표시하지 않고, 기존 빈 상태 컴포넌트로 연동이 필요한 영역을 드러낸다. 실제 실행 환경에서 Supabase 설정이 있으면 API 구현이 기본값이다.

| Feature | 상태 | 사유 |
|---|---|---|
| Chat | MOCK | Backend Chat API가 고정 안내를 반환하는 stub이다. |
| 식사 대체 메뉴 생성 | MOCK | 실제 대체 메뉴를 생성하는 Backend API가 없고 Chat도 stub이다. |

## BLOCKED (해제됨, 2026-09-20)

Guide 응답(`GET /meals|household|health|sleep/today`)의 각 항목에 `item_id`(routine_items.id)가 추가되어(`app/domains/guide/schemas.py`, `query_service.py`), 아래 3개 기능이 요구하던 `item_id`를 Frontend가 이제 직접 받을 수 있다. Frontend 쪽 연결 작업만 남았다.

| Feature | 계약 |
|---|---|
| 건강·가사·수면 루틴 실행 완료 기록 | `PUT /care/routine-items/{item_id}/execution` — Guide 응답의 `item_id` 사용 |
| 식사 메뉴 수락·거절·교체 피드백 | `PUT /care/routine-items/{item_id}` — Guide 응답의 `item_id` 사용 |
| 수면 환경 override | `PUT /care/routine-items/{item_id}/sleep-environment` — Guide 응답의 `item_id` 사용 |

## 상태 및 오류 처리

- `200/201`: 데이터 상태
- `404`: 빈 상태
- `401/403`: 로그인 또는 권한 오류
- `409/422`: 도메인 충돌 또는 입력 오류
- `503`: 서버 연결 오류
- 기타: 일반 오류

새로 연결한 화면은 기존 `AppLoadingState`, `AppEmptyState`, `AppErrorState`를 재사용한다.
