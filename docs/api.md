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
| POST | `/api/v1/family/household-requests/{requestId}/items/{itemId}/confirm` | 항목(카드) 단위 미확인 → 확인 | FUC-H-REQUEST-002 |
| POST | `/api/v1/family/household-requests/{requestId}/items/{itemId}/complete` | 항목(카드) 단위 확인 → 완료 | FUC-H-REQUEST-002~003 |
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

토큰 검증 뒤에는 `motion_consents`를 확인한다(2026-09-18 추가, NFR-012): 동의가 없거나 수집이
OFF면 **4003**(앱 정의 코드)으로 닫아 1008(origin/토큰)과 구분한다 — 클라이언트는 4003에서
동의 화면으로 유도하면 된다. 동의 조회 자체가 실패하면 열어주지 않고 1011로 닫는다. 검사는
연결 시점 한 번이므로, 스트림 중 철회 시에는 클라이언트가 WS를 끊어야 한다.

`GET /events`·`GET /report/daily`는 호출자가 `partner_links`에 남편으로 등록돼 있으면 연동된
아내의 데이터를 돌려준다(2026-09-18 추가, `app/api/v1/partner_scope.py` — 캘린더와 같은 규칙).
미연동이면 본인 데이터(남편은 사실상 빈 결과). `/live`는 데모 단일 세션이라 그대로다.

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
파이프라인 설계: `docs/ai_wednesday/Ai_wednesday_pipeline_v3.md`.

| Method | Path | 화면 | 성공 응답 | 설명 |
| --- | --- | --- | --- | --- |
| GET | /api/v1/routine/today | 홈 재진입 | 200 루틴 | 오늘(KST) 저장된 4종 가이드. 없으면 404 → 앱은 컨디션 CTA 표시 |
| POST | /api/v1/routine/today | 예정 활동 선택 완료 직후 | 201 루틴 | 프로필·오늘 컨디션(+서버가 읽는 전일 루틴 완료 현황·전일 모션 요약, 없으면 생략)으로 AI 루틴 생성·저장. AI 실패·10초 초과 시 전일 루틴 → 기본 템플릿 순으로 폴백해 **항상 4종을 돌려준다**. 오늘 확정 전 루틴이 있으면 **컨디션 수정 경로**(아래) |

호출 순서 (W-COND-001 → W-TASK-001 → W-HOME-001)

1. `PUT /api/v1/care/conditions/{date}`: 오늘 컨디션 7개 점수 저장
2. `PUT /api/v1/care/conditions/{date}/activities`: 오늘 예정 활동 저장(`{"activities": ["빨래", "청소", ...]}`). 활동을 안 골라도 빈 목록으로 호출 가능
3. `POST /api/v1/routine/today`: 루틴 생성. 1번을 하지 않았으면 409(`오늘 컨디션을 먼저 입력해 주세요.`)

예정 활동 코드표 (S6). 앱은 한글 라벨을 그대로 보내고 DB에도 라벨로 저장된다. 루틴 생성 시 백엔드가 코드로 바꾸고, 가사 항목의 `item_key`는 `household:<코드>`가 된다.

| 라벨 | 코드 | 라벨 | 코드 |
| --- | --- | --- | --- |
| 장보기 | `groceries` | 쓰레기 배출 | `trash` |
| 빨래 | `laundry` | 침구 정리 | `bedding` |
| 청소 | `cleaning` | 화분 관리 | `plants` |
| 설거지 | `dishes` | 정리 정돈 | `tidying` |
| 요리 | `cooking` | 직접 입력(목록 밖 라벨) | `custom` |

직접 입력이 여러 개면 `household:custom`, `household:custom:2`처럼 번호가 붙는다. 라벨 글자가 위 표와 다르면(띄어쓰기 포함) 직접 입력으로 처리되므로, 앱은 표의 라벨을 그대로 보낸다.

응답 본문 (두 API 공통)

| 필드 | 설명 |
| --- | --- |
| id, date, generated_at | `daily_routines` 행 |
| revision | 같은 날짜의 루틴 버전 번호(1부터). 같은 날 다시 POST할 때마다 1씩 커진다. GET은 가장 큰 revision을 돌려준다 |
| is_regeneration | `revision > 1`이면 `true` = 같은 날 재생성된 루틴. 프론트는 변경 배너, 남편 알림(FUC-W-COND-003)은 이 값으로 분기한다. 첫 생성이면 `false` |
| change_summary | 직전 버전 대비 변화. `{added, updated, removed, unchanged}` 각각 `item_key` 목록. 첫 생성이면 `null`. `updated`는 제목이 바뀐 항목(완료 기록은 유지). 컨디션 수정 경로에서는 `categories`(다시 만든 가이드)·`conditions`(바뀐 컨디션 키)도 함께 온다 |
| confirmed_at | '저장하고 마치기'로 확정한 시각. `null` = 확정 전 (확정 API는 아직 없음) |
| source | `ai` = AI 생성 성공(컨디션 수정 시 대상 가이드 중 하나 이상 성공). `fallback_prev`(전일 루틴 또는 직전 버전 유지) / `fallback_template`(기본 템플릿) = **AI 생성 실패**(시간 초과·AI 오류). 처리 기준은 아래 "AI 실패 처리". 폴백률(NFR-016) 측정용 |
| model | 생성에 쓴 LLM 모델명. 폴백이면 `null` |
| response | `{meal: [...], household: [...], health: [...], sleep: {...}, tip: {...} 또는 null}`. `tip`은 웰컴 카드 '오늘 시도해보세요' 팁 1개(아래 표). 나머지 4종은 각 항목 `{item_key, title, payload, source_ids}`. `payload` 모양은 아래 표. `source_ids`는 근거 문단 `pregnancy_knowledge.id` |

`payload` 모양 (카테고리별, 기준 코드 `backend/app/services/routine/prompt.py` `ROUTINE_SCHEMA`)

| 카테고리 | payload |
| --- | --- |
| meal (배열) | `{period: breakfast\|lunch\|dinner\|snack, reasonTitle, reason, evidence, nutritionTags: [문자열], cautions: [{title, description, badge}]}` |
| household (배열) | `{owner: self\|appliance\|partner, applianceAction: now\|reserve\|night\|none, reason}` |
| health (배열) | `{bodyArea, loads: [{area, label, value(숫자)}], guide, durationMin(정수), reason}` |
| sleep (객체 1개) | `{recommendedBedtime, environments: [{type, value, options: [문자열]}], tips: [문자열], reason}` |

`response.tip` (S7, FUC-W-HOME-001): `{text: 문자열(한 문장, 40자 안팎), source_ids: [정수]}` 또는 `null`. 루틴 항목이 아니므로 `item_key`·완료 체크가 없다. `null`인 경우 — 폴백 루틴(`source != ai`), 팁 생성만 실패·지연, 알레르기 금지어 포함 — 앱은 기본 문구를 표시한다. 팁이 `null`이어도 4종 루틴은 정상(`source`는 그대로).

| 상태 코드 | 의미 |
| --- | --- |
| 401 | 토큰 없음 또는 유효하지 않음 |
| 404 | 오늘 생성된 루틴 없음 (GET) |
| 409 | 프로필 1단계(출산예정일) 또는 오늘 컨디션이 아직 없음 (POST). `detail`에 어느 쪽인지 문구 |
| 503 | Supabase 설정 누락 또는 연결 실패 |

같은 날 다시 POST하면 `daily_routines`에 새 revision 행이 쌓이고(이전 버전은 보존), `routine_items`는 같은 `item_key`의 행을 고쳐 씁니다. 같은 키 항목은 제목이 바뀌어도 완료 기록(`status`·`completed_at`·`completed_by`)이 유지되고, 변화는 `routine_items.change_kind`(`added`/`updated`/`removed`, 변화 없으면 `null`)로 표시됩니다.

AI 실패 처리 (FUC-W-CALLBACK-001, W-CALLBACK-001)

- 백엔드는 AI가 실패해도 폴백 루틴을 저장하고 **201**을 돌려준다(빈 화면 0건, NFR-016). HTTP 오류로 실패를 알리지 않는다.
- 앱은 POST 응답의 `source`로 판단한다.
  - `source == "ai"`: 정상. 홈에 4종 가이드를 표시한다.
  - `source != "ai"`: AI 실패. 실패 안내 화면(W-CALLBACK-001)과 '다시 시도하기'를 띄운다.
- '다시 시도하기' = 같은 `POST /api/v1/routine/today`를 다시 호출한다(저장된 컨디션·예정 활동을 그대로 쓴다). 성공하면 `source == "ai"`, `revision`이 1 커진 응답이 온다.
- 재시도하지 않거나 연속 실패하면 **이미 받은 응답의 `response`(폴백 루틴)를 그대로 표시**한다. 앱 자체 목업 폴백은 쓰지 않는다.
- `GET /api/v1/routine/today`도 같은 규칙: 마지막 버전의 `source`가 `ai`가 아니면 실패 안내를 띄울 수 있다.
- 남편 알림(FUC-W-COND-002/003)은 `source == "ai"`일 때만 백엔드가 보낸다. 오늘 첫 AI 루틴이면 오전 리포트, 이미 AI 루틴이 있었으면 루틴 변경 알림이다(폴백 뒤 재시도 성공은 오전 리포트).

컨디션 수정 경로 (FUC-W-COND-003, S10)

- 조건: 오늘 루틴이 있고 확정 전(`confirmed_at == null`)이며 직전 버전이 `source == "ai"`일 때 `POST`를 다시 호출하면 적용된다. 직전 버전이 폴백이면 4종 전체를 다시 만든다(재시도).
- 서버가 직전 버전 생성 당시 컨디션·예정 활동과 지금 값을 비교해 **바뀐 가이드만** 다시 만든다. 나머지 가이드는 그대로이고 완료 체크도 유지된다.
- 컨디션이 하나도 안 바뀌었으면 **새 버전 없이 현재 루틴을 그대로** 돌려준다(`revision` 그대로, 남편 알림 없음).
- 다시 만들던 가이드 일부가 실패하면 그 가이드는 직전 내용을 유지하고 `source == "ai"`다. 대상 가이드가 모두 실패하면 `source == "fallback_prev"`(직전 버전 유지)이고, 앱은 위 규칙대로 실패 안내·다시 시도하기를 띄운다. 다시 시도하면 실패했던 가이드만 다시 만든다.
- 확정 후 다시 입력(FUC-W-COND-004)은 4종 전체를 새로 만든다. 확정 API는 아직 없다.

로컬 Flutter Web의 임의 개발 포트를 허용합니다.
허용 origin은 `http://localhost[:port]`, `http://127.0.0.1[:port]`입니다.
Authorization, Content-Type 헤더와 GET/POST/PUT/PATCH/DELETE/OPTIONS 메서드를 허용합니다.   
