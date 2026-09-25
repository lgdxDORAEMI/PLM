# Frontend API Integration Status

- 갱신일: 2026-09-23
- 기준: Supabase 설정이 있으면 API 구현을 사용한다. 설정이 없는 실행 화면은 Mock 값 대신 `연동이필요합니다` 빈 상태를 표시한다. 테스트에서 명시한 경우에만 Mock 화면 값을 표시한다.
- 공통 경로: `Screen → Controller/Store → Repository/Service → ApiClient → Backend`
- Frontend Feature 코드는 Supabase Table 또는 RPC를 직접 호출하지 않는다.

## 실제 API 연결

| Feature | Frontend 상태 | Backend API |
|---|---|---|
| 앱 진입 분기 | CONNECTED | `GET /api/v1/account/bootstrap` |
| 프로필 설정(생년월일 포함) | CONNECTED | `GET /api/v1/profile/me`, `PUT /api/v1/profile/me/*` (2026-09-20: `birth_date` 실연결, 안 쓰이던 `/account/profile` 제거) |
| 배우자 초대 발급 | CONNECTED | `POST /api/v1/account/partner-invitations` (초대 화면 기본 버튼 연결) |
| 배우자 연결 상태 | CONNECTED | `GET /api/v1/account/partner-link` |
| 오늘 컨디션·예정 활동 | CONNECTED | `GET/PUT /api/v1/care/conditions/{date}`, `PUT .../activities` |
| 오늘 루틴·재생성 | CONNECTED | `GET/POST /api/v1/routine/today` |
| 홈 주차별 안내 | CONNECTED | `GET /api/v1/routine/home` (컨디션·오늘 루틴 생성 전에도 조회) |
| 식사 가이드 조회 | CONNECTED | `GET /api/v1/meals/today` |
| 식사 메뉴 수락·거절 피드백 | CONNECTED | `PUT /api/v1/care/routine-items/{item_id}` (Guide `item_id` 사용) |
| Chat 대화·이력·루틴 수정 | CONNECTED | `GET/POST /api/v1/chat/messages`, `GET/POST .../{message_id}/routine-update` |
| 식사 대체 메뉴 생성 | CONNECTED | `POST /api/v1/chat/meal-alternative`; Chat 응답의 저장된 `recommendation` 카드도 복원 |
| 가사 가이드 조회 | CONNECTED | `GET /api/v1/household/today` |
| 가사 요청 생성·목록·상세·확인·완료 | CONNECTED | `/api/v1/family/household-requests/**` |
| 건강 가이드 조회 | CONNECTED | `GET /api/v1/health/today` |
| 수면 가이드 조회 | CONNECTED | `GET /api/v1/sleep/today` |
| Daily 리포트·캘린더 | CONNECTED | `/api/v1/care/daily-reports/**`, `GET /api/v1/care/calendar/{month}`, `GET /api/v1/care/calendar/days/{target_date}` |
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
| 별도 Mock 제품 기능 | 없음 | 제품 경로는 위 API를 사용하며 Mock은 Widget 테스트와 명시적 preview에만 사용한다. |

## 루틴 항목 연결 상태

Guide 응답(`GET /meals|household|health|sleep/today`)의 각 항목에 `item_id`(routine_items.id)가 포함된다. 아래 API는 기존 화면 액션에서 이 값을 사용한다.

| Feature | 계약 |
|---|---|
| 건강 루틴 실행 완료 기록 | `PUT /care/routine-items/{item_id}/execution` — 연결됨 |
| 식사 메뉴 수락·거절 피드백 | `PUT /care/routine-items/{item_id}` — 연결됨 |
| 수면 환경 override | `PUT /care/routine-items/{item_id}/sleep-environment` — 연결됨 |

## 상태 및 오류 처리

- `200/201`: 데이터 상태
- `404`: 빈 상태
- `401/403`: 로그인 또는 권한 오류
- `409/422`: 도메인 충돌 또는 입력 오류
- `503`: 서버 연결 오류
- 기타: 일반 오류

새로 연결한 화면은 기존 `AppLoadingState`, `AppEmptyState`, `AppErrorState`를 재사용한다.
