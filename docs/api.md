# API

## Contract First Backend Skeleton

아래 API는 Frontend 병렬 연동을 위한 안정 계약이다. 현재 `account`, `care`, `family` 구현은 인증된 사용자 ID를 받는 메모리 Stub이며, 실제 Repository adapter로 교체해도 URL과 Schema를 유지한다. 모든 경로는 `Authorization: Bearer <Supabase access token>`을 요구한다.

### Account

| Method | Path | Response | 관련 요구사항 |
|---|---|---|---|
| GET | `/api/v1/account/bootstrap` | 역할, Profile 완료 상태, Partner 연동 상태, 진입 목적지 | FUC-B-ENTRY-001 |
| GET/PUT | `/api/v1/account/profile` | 6단계 Profile 최종본 조회·원자적 저장 | FUC-W-PROFILE-001~009 |
| GET | `/api/v1/account/partner-link` | 연동 여부와 표시명 | FUC-W-MENU-001 |
| POST | `/api/v1/account/partner-invitations` | 72시간 이내 만료되는 초대 URL | FUC-W-INVITE-001, NFR-026 |

`destination`은 `wife_profile`, `wife_home`, `husband_invitation_required`, `husband_calendar` 중 하나다. 초대 수락 API는 화면과 인증 복귀 계약이 미확정이므로 TBD다.

### Care

| Method | Path | 역할 | 관련 요구사항 |
|---|---|---|---|
| GET/PUT | `/api/v1/care/conditions/{date}` | 날짜별 7개 컨디션 점수 조회·저장 | FUC-W-COND-001~004 |
| PUT | `/api/v1/care/conditions/{date}/activities` | 예정 집안일과 직접 입력 항목 저장 | FUC-W-TASK-001 |
| PUT | `/api/v1/care/routine-items/{itemId}/execution` | 직접 행동 완료·취소 기록 | FUC-W-RECORD-001 |
| POST | `/api/v1/care/daily-reports/{date}/preview` | Daily report 미확정 집계 | FUC-W-HOME-002, FUC-W-REPORT-001 |
| POST | `/api/v1/care/daily-reports/{date}/finalize` | 명시적 저장과 루틴 확정 | FUC-W-REPORT-001, NFR-028 |
| GET | `/api/v1/care/daily-reports/{date}` | 날짜당 단일 Daily report 조회 | FUC-W-REPORT-001~002 |
| GET | `/api/v1/care/calendar/{YYYY-MM}` | 기록이 있는 날짜의 Calendar read model | FUC-B-CAL-001 |

컨디션 응답의 `write_kind`는 `created`, `updated`, `new_routine_required`다. 확정 리포트 이후 같은 날짜의 컨디션을 다시 저장하면 `new_routine_required`를 반환해 기존 확정 루틴을 덮어쓰지 않는다.

### Family

| Method | Path | 역할 | 관련 요구사항 |
|---|---|---|---|
| POST/GET | `/api/v1/family/household-requests` | 가사 요청 생성·목록 조회 | FUC-W-HOUSE-003, FUC-H-REQUEST-001 |
| GET | `/api/v1/family/household-requests/{requestId}` | 권한이 있는 부부의 요청 조회 | FUC-H-REQUEST-001 |
| POST | `/api/v1/family/household-requests/{requestId}/confirm` | 미확인 → 확인 | FUC-H-REQUEST-002 |
| POST | `/api/v1/family/household-requests/{requestId}/complete` | 확인 → 완료 | FUC-H-REQUEST-002~003 |
| GET | `/api/v1/family/notifications` | 오전 리포트·가사 요청·컨디션 변경 알림 | FUC-H-NOTI-001~002 |
| POST | `/api/v1/family/notifications/{notificationId}/read` | 알림 읽음 처리 | FUC-H-NOTI-001 |
| GET | `/api/v1/family/morning-reports/{date}` | 남편 공유 범위의 오전 요약 | FUC-H-REPORT-001, NFR-013 |
| GET | `/api/v1/family/motion/privacy` | 동의와 수집 ON/OFF 상태 | FUC-B-MOTION-001, NFR-012 |
| PUT/DELETE | `/api/v1/family/motion/consent` | 수집 동의·철회 | NFR-012 |
| PUT | `/api/v1/family/motion/collection` | 신규 Motion 감지만 ON/OFF | FUC-B-MOTION-001 |

가사 요청에는 거절 상태가 없다. 확인·완료 전환은 받은 남편만 수행하며 상태 변경으로 새 알림을 생성하지 않는다. Motion OFF와 동의 철회 모두 기존 기록을 삭제하지 않는다.

개발 기본 주소: `http://localhost:8000`

## 최근 변경사항 (프론트 영향)

- 2026-09-16: `GET /api/v1/movement/report/daily` 응답에 `bending_burden_event_count`(int) 필드 추가 — Bending의 Repeated Load/Prolonged Load와 High-load Action(Sit-to-Stand) 포착 횟수를 합친 값. 상세는 아래 `/report/daily` 집계 방식 참고.

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

`CORSMiddleware`는 WebSocket 핸드셰이크에는 적용되지 않아서, `/live/stream`은 연결을 수락하기
전에 `Origin` 헤더를 따로 확인한다(2026-09-15 추가, 아래 HTTP CORS와 동일한 규칙 재사용).
허용되지 않은 origin이거나 origin이 없으면 코드 1008(정책 위반)로 바로 닫는다.

### `/report/daily` 집계 방식

`(posture_type, burden_label)` 조합별로 그날 이벤트를 묶어 `count`/`total_duration_sec`/
`max_duration_sec`를 계산한다. `top_burdened_body_part`는 **지속시간 합이 아니라
`count × 라벨 심각도`로 점수를 매겨** 고른다 — Sit-to-Stand는 설계상 항상
`duration_sec=0`인 순간 이벤트라서, 지속시간 합으로만 고르면 하루에 몇 번을 반복해도
절대 1위가 될 수 없기 때문이다(`backend/app/services/movement/report.py`의
`_pick_top_burdened()` 주석 참고). 문구는 `report_templates.yaml`에서 트리거 사유별로
가져오며 Repeated Load 이상인 조합에만 생성한다.

`bending_burden_event_count`(2026-09-16 추가)는 Bending의 Repeated Load/Prolonged Load
이벤트와 High-load Action(Sit-to-Stand) 이벤트의 개수를 합친 값이다. High-load Action은
무릎 동작이라 `posture_type`이 실제로는 거의 항상 Standing으로 기록되지만, 이 필드에는
`posture_type`과 무관하게 항상 포함된다 — `aggregates` 배열의 개별 조합과는 다른, 별도로
계산된 요약값이다(`report.py`의 `_count_bending_burden_events()` 참고).

## 임산부 프로필 (W-PROFILE-001, 화면설계서: 프로필 설정)

모든 요청에 `Authorization: Bearer <Supabase access token>`이 필요합니다.
프로필 설정은 단계마다 저장합니다. 3~6단계는 화면설계서가 확정되면 같은 방식으로 추가합니다.

| Method | Path | 화면 | 성공 응답 | 설명 |
| --- | --- | --- | --- | --- |
| GET | /api/v1/profile/me | 이어하기·진행바 | 200 프로필 | 내 프로필 조회 |
| PUT | /api/v1/profile/me/due-date | 프로필 설정 1/6 | 200 프로필 | 출산예정일 저장 |
| PUT | /api/v1/profile/me/body | 프로필 설정 2/6 | 200 프로필 | 임신 전 신장·체중 저장 |

요청 본문: `PUT /api/v1/profile/me/due-date` (둘 중 하나 이상, 출산예정일이 기본 입력)

| 필드 | 타입 | 규칙 |
| --- | --- | --- |
| due_date | `YYYY-MM-DD` | 오늘(KST) 기준 14일 전 ~ 365일 후. 병원에서 진단받은 값을 그대로 저장한다 |
| last_period_start | `YYYY-MM-DD` | 선택 입력. 미래 날짜는 거부한다. `due_date` 없이 이 값만 보내면 서버가 `+280일`로 출산예정일을 계산해 함께 저장한다. 둘 다 보내면 `due_date`를 그대로 쓰고 이 값은 보낸 그대로 저장한다(초음파 보정으로 280일과 어긋나도 허용) |

`due_date`만 보내면 이전에 저장된 `last_period_start`는 비워집니다. 다른 단계 값은 유지됩니다.

요청 본문: `PUT /api/v1/profile/me/body` (두 필드 모두 필수)

| 필드 | 타입 | 규칙 |
| --- | --- | --- |
| height_cm | 숫자 | 100 ~ 250, 소수 첫째 자리까지 |
| pre_pregnancy_weight_kg | 숫자 | 30 ~ 200, 소수 첫째 자리까지 |

응답 본문 (세 API 공통)

| 필드 | 설명 |
| --- | --- |
| due_date, last_period_start, height_cm, pre_pregnancy_weight_kg | 저장된 값. 아직 입력하지 않은 단계는 `null` |
| pregnancy_weeks, pregnancy_days | 저장하지 않고 조회 시점(KST)에 `출산예정일 - 280일`을 시작일로 계산한 임신 주수 |
| completed_step | 연속으로 완료한 단계 수(현재 1~2). 진행바·이어하기에 사용 |

| 상태 코드 | 의미 |
| --- | --- |
| 401 | 토큰 없음 또는 유효하지 않음 |
| 404 | 등록된 프로필 없음 (GET) |
| 409 | 출산예정일(1단계)을 저장하기 전에 신장·체중(2단계)을 보냄 |
| 422 | 입력 검증 실패. 필드 오류는 `detail[].loc`의 마지막 값이 필드명, 본문 전체 규칙 오류(두 값 모두 누락, 미래 생리 시작일, 출산예정일 범위 초과)는 `loc`이 `["body"]` |
| 503 | Supabase 설정 누락 또는 연결 실패 |

## AI 하루 루틴 (W-ROUTINE-001/003, W-HOME-001)

모든 요청에 `Authorization: Bearer <Supabase access token>`이 필요합니다. 구현: `backend/app/api/v1/routine.py`,
파이프라인 설계: `docs/ai_routine/AI_루틴_파이프라인.md`.

| Method | Path | 화면 | 성공 응답 | 설명 |
| --- | --- | --- | --- | --- |
| GET | /api/v1/routine/today | 홈 재진입 | 200 루틴 | 오늘(KST) 저장된 4종 가이드. 없으면 404 → 앱은 컨디션 CTA 표시 |
| POST | /api/v1/routine/today | 예정 활동 선택 완료 직후 | 201 루틴 | 프로필·오늘 컨디션으로 AI 루틴 생성·저장. AI 실패·10초 초과 시 전일 루틴 → 기본 템플릿 순으로 폴백해 **항상 4종을 돌려준다** |

응답 본문 (두 API 공통)

| 필드 | 설명 |
| --- | --- |
| id, date, generated_at | `daily_routines` 행 |
| source | `ai` / `fallback_prev`(전일 루틴 복사) / `fallback_template`(기본 템플릿). 폴백률(NFR-016) 측정용 |
| model | 생성에 쓴 LLM 모델명. 폴백이면 `null` |
| response | `{meal: [...], household: [...], health: [...], sleep: {...}}`. 각 항목 `{item_key, title, payload, source_ids}`. `payload` 모양은 `docs/DB_ERD_스키마.md` §3.2 카테고리별 정의와 같다. `source_ids`는 근거 문단 `pregnancy_knowledge.id` |

| 상태 코드 | 의미 |
| --- | --- |
| 401 | 토큰 없음 또는 유효하지 않음 |
| 404 | 오늘 생성된 루틴 없음 (GET) |
| 409 | 프로필 1단계(출산예정일) 또는 오늘 컨디션이 아직 없음 (POST). `detail`에 어느 쪽인지 문구 |
| 503 | Supabase 설정 누락 또는 연결 실패 |

같은 날 다시 POST하면 `daily_routines`는 덮어쓰고 `routine_items`는 지우고 다시 넣습니다(완료 체크 유지 정책은 W-RECORD-001에서 정함).

로컬 Flutter Web의 임의 개발 포트를 허용합니다.
허용 origin은 `http://localhost[:port]`, `http://127.0.0.1[:port]`입니다.
Authorization, Content-Type 헤더와 GET/POST/PUT/PATCH/DELETE/OPTIONS 메서드를 허용합니다.   
