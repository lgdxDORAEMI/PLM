# API

개발 기본 주소: `http://localhost:8000`

| Method | Path | 200 응답 | 설명 |
| --- | --- | --- | --- |
| GET | / | `{"message":"PLM API","status":"ok"}` | API 기본 상태 |
| GET | /health | `{"status":"healthy"}` | 프로세스 상태 |
| WS | /api/v1/movement/live/stream | JSON 메시지 스트림 | 카메라 프레임을 받아 캘리브레이션→실시간 판정을 수행 (B-1/B-3, 실제 동작). 프로토콜은 아래 참고 |
| GET | /api/v1/movement/live | `LiveAccumulatedState` (없으면 404) | 실시간 탭 조회 — 호출 시점까지 누적된 상태를 반환하는 풀(pull) 방식, 푸시 알림 아님 (W-MOTION-001). **실제 동작**, 활성 세션 없으면 404 |
| GET | /api/v1/movement/events | `PostureEvent[]` | 이벤트 로그 조회. **실제 동작** (`EventStore`에 쌓인 값) |
| GET | /api/v1/movement/report/daily | `DailyReportSummary` | 일일 리포트 조회, 부위별 최다 부담 포함 (W-REPORT-002). **실제 동작**. `?date=YYYY-MM-DD` 쿼리 파라미터로 날짜 지정(기본값 오늘, UTC) |

`/health`는 외부 서비스나 DB 연결 상태를 확인하지 않습니다.
Swagger UI: `/docs`, OpenAPI schema: `/openapi.json`.
현재 상태 확인 API는 인증 없이 호출할 수 있습니다.

`/api/v1/movement/*`는 `backend/app/api/v1/movement.py`에 정의되어 있습니다. 응답 스키마는
`backend/app/schemas/movement.py`에 정의되어 있고, 설계 배경은 `docs/movement/구현계획서_v3.md`를
참고하세요. `POST /calibration/start`는 더 이상 없습니다 — 캘리브레이션이 필요하면
`/live/stream` 연결 시 자동으로 시작되므로 별도 REST 호출이 필요 없습니다.

### `/live/stream` WebSocket 프로토콜

1. 연결하면 서버가 세션을 만든다. 기존 캘리브레이션이 없으면 캘리브레이션 단계로 들어간다.
2. 클라이언트는 JPEG로 인코딩한 프레임을 계속 바이너리로 보낸다.
3. 캘리브레이션 중에는 서버가 매 프레임 `{"type": "calibration_progress", "collected": n, "target": n}`을
   보내고, 충분히 모이면 `{"type": "calibration_done"}`을 보낸 뒤 실시간 판정으로 전환한다.
4. 실시간 판정 단계에서는 매 프레임 `{"type": "frame", "data": <PostureFrameState>}`를 보낸다.
5. 연결이 끊기면 서버가 세션을 정리한다 (열려 있던 이벤트는 그 시점으로 닫아 `EventStore`에 기록).

이 프로토콜은 데모 전용이며 동시에 한 세션만 가정한다(`_current_session_id` 전역 변수).
실제 다중 사용자 서비스에서는 인증 컨텍스트별로 세션을 조회하는 방식으로 바꿔야 한다.

### `/report/daily` 집계 방식

`(posture_type, burden_label)` 조합별로 그날 이벤트를 묶어 `count`/`total_duration_sec`/
`max_duration_sec`를 계산한다. `top_burdened_body_part`는 **지속시간 합이 아니라
`count × 라벨 심각도`로 점수를 매겨** 고른다 — Sit-to-Stand는 설계상 항상
`duration_sec=0`인 순간 이벤트라서, 지속시간 합으로만 고르면 하루에 몇 번을 반복해도
절대 1위가 될 수 없기 때문이다(`backend/app/services/movement/report.py`의
`_pick_top_burdened()` 주석 참고). 문구는 `report_templates.yaml`에서 트리거 사유별로
가져오며 Repeated Load 이상인 조합에만 생성한다.

## 임산부 프로필 (W-PROFILE-001)

모든 요청에 `Authorization: Bearer <Supabase access token>`이 필요합니다.

| Method | Path | 성공 응답 | 설명 |
| --- | --- | --- | --- |
| POST | /api/v1/profile | 201 프로필 + 임신 주수 | 프로필 입력 및 저장 (사용자당 1개) |
| GET | /api/v1/profile/me | 200 프로필 + 임신 주수 | 내 프로필 조회 |

요청 본문 (POST)

| 필드 | 타입 | 규칙 |
| --- | --- | --- |
| due_date | `YYYY-MM-DD` | 오늘(KST) 기준 14일 전 ~ 280일 후 |
| age | 정수 | 15 ~ 55 |
| height_cm | 숫자 | 100 ~ 250, 소수 첫째 자리까지 저장 |
| pre_pregnancy_weight_kg | 숫자 | 30 ~ 200, 소수 첫째 자리까지 저장 |
| parity | 문자열 | `primiparous`(초산) / `multiparous`(경산) |
| fetus_count | 문자열 | `singleton`(단태아) / `multiple`(다태아) |

응답 본문은 요청 필드에 `pregnancy_weeks`, `pregnancy_days`를 더한 형태입니다.
임신 주수는 저장하지 않고 조회 시점(KST)에 `출산예정일 - 280일`을 시작일로 계산합니다.

| 상태 코드 | 의미 |
| --- | --- |
| 401 | 토큰 없음 또는 유효하지 않음 |
| 404 | 등록된 프로필 없음 (GET) |
| 409 | 이미 등록된 프로필 있음 (POST) |
| 422 | 입력 검증 실패. `detail[].loc`의 마지막 값이 필드명 |
| 503 | Supabase 설정 누락 또는 연결 실패 |

로컬 Flutter Web의 임의 개발 포트를 허용합니다.
허용 origin은 `http://localhost[:port]`, `http://127.0.0.1[:port]`입니다.
Authorization, Content-Type 헤더와 GET/POST/PUT/PATCH/DELETE/OPTIONS 메서드를 허용합니다.
