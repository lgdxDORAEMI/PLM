# PLM API

현재 `backend/app/main.py`에 등록된 FastAPI 라우터를 기준으로 작성했습니다. 기본 경로는 `/api/v1`입니다. 실행 중인 서버의 필드별 OpenAPI 계약은 `/docs` 또는 `/openapi.json`에서 확인할 수 있습니다.

## 공통 규칙

- `GET /`은 서비스 정보, `GET /health`는 프로세스 상태를 반환합니다. `/health`는 DB·외부 서비스 연결을 검사하지 않습니다.
- Render Health Check용 `GET /health`의 정상 응답은 `{"status":"ok"}`입니다.
- 아래에서 별도 표기하지 않은 HTTP API는 `Authorization: Bearer <Supabase access token>`이 필요합니다. 남편이 아내 데이터를 읽는 경로는 `partner_links`의 연결 관계를 확인합니다.
- 날짜 경로는 `YYYY-MM-DD`, 월 경로는 `YYYY-MM`입니다. `today`와 날짜 생략 시 기준은 서버의 KST 오늘입니다.
- 일반적인 오류: 401 인증 실패, 403 역할·권한 제한, 404 대상 데이터 없음, 409 선행 입력 또는 상태 충돌, 422 요청 검증 실패, 503 저장소·외부 연결 불가. 실제 응답은 엔드포인트별로 달라집니다.
- API 실패 시 클라이언트가 Mock 데이터로 자동 대체하는 계약은 없습니다.

## 계정과 프로필

| 메서드 | 경로 | 요청·결과 |
| --- | --- | --- |
| POST | `/account/session/default` | 로컬 실행 환경에서 사전 설정된 아내 계정 세션 발급. Bearer 토큰 예외 |
| POST | `/account/session/switch` | 로컬의 설정된 계정만 `target`이 `wife` 또는 `husband`인 본문으로 전환 |
| GET | `/account/bootstrap` | 역할, 프로필 완료 상태, 배우자 연결 상태와 시작 목적지 |
| GET | `/account/partner-link` | 연결 상태와 본인·배우자 표시 이름 |
| POST | `/account/partner-invitations` | 만료 시각이 있는 초대 링크 발급; 201 |
| POST | `/account/partner-invitations/{token}/accept` | 로그인한 배우자가 초대 수락 |
| GET | `/profile/me` | 임산부 프로필과 계산된 임신 주수 조회 |
| PUT | `/profile/me/due-date` | 출산 예정일 또는 마지막 생리 시작일 저장 |
| PUT | `/profile/me/body` | 키·임신 전 체중 저장 |
| PUT | `/profile/me/pregnancy-history` | 임신 이력 저장 |
| PUT | `/profile/me/pregnancy-count` | 임신 횟수 저장 |
| PUT | `/profile/me/allergies` | 알레르기 저장 |
| PUT | `/profile/me/medical-notes` | 병원 주의사항 저장 |

`/account/session/default`와 `/account/session/switch`는 요청 클라이언트가 서버의 localhost일 때만 허용됩니다. 계정 비밀번호는 백엔드 설정에만 둡니다. 프로필 필드의 정확한 필수 여부와 범위는 OpenAPI 스키마를 따릅니다.

## 오늘 기록과 루틴

| 메서드 | 경로 | 요청·결과 |
| --- | --- | --- |
| POST | `/care/today/reset` | 로그인한 아내의 KST 오늘 기록 초기화; 아래 초기화 절 참고 |
| GET · PUT | `/care/conditions/{target_date}` | 컨디션 조회·저장; 저장 결과에 `write_kind`, `changed_fields` 포함 |
| PUT | `/care/conditions/{target_date}/activities` | `{"activities":[...]}`로 예정 활동 저장 |
| GET | `/routine/today` | KST 오늘의 최신 저장 루틴과 홈 요약; 없으면 404 |
| POST | `/routine/today` | 프로필·컨디션 기반 루틴 생성 또는 재생성; 201 |
| PUT | `/care/routine-items/{item_id}/execution` | `status`가 `scheduled`, `completed`, `skipped`, `needs_confirmation` 중 하나인 본문으로 실행 상태 기록 |
| PUT | `/care/routine-items/{item_id}` | `feedback_kind`와 `payload`로 식사 메뉴 피드백·교체 저장 |
| PUT | `/care/routine-items/{item_id}/sleep-environment` | 조명·온도·습도·소리·공기청정기 설정 저장 |
| POST | `/care/daily-reports/{target_date}/preview` | 실행 결과의 미확정 리포트 집계 |
| POST | `/care/daily-reports/{target_date}/finalize` | 리포트 저장·확정 |
| GET | `/care/daily-reports/{target_date}` | 저장된 날짜별 리포트 조회 |
| GET | `/care/calendar/{month}` | 날짜별 컨디션 지수·리포트 상태 조회 |

컨디션 입력은 `nausea`, `waist_pain`, `pelvis_pain`, `leg_pain`, `wrist_pain`, `fatigue`, `mood`의 1~5 점수 7개를 요구합니다. 화면에 기분을 표시하지 않더라도 API 요청에는 `mood`가 필요합니다. 루틴 생성은 프로필과 오늘 컨디션 저장 후 호출하며, 반환값의 `source`와 `revision`으로 AI/폴백 및 재생성 여부를 구분합니다. 컨디션을 바꾼 경우 기존 확정 리포트와 루틴 상태를 고려해 `write_kind=new_routine_required`가 반환될 수 있습니다.

## 네 가지 상세 가이드와 ThinQ

| 메서드 | 경로 | 결과 |
| --- | --- | --- |
| GET | `/meals/today?date=YYYY-MM-DD` | 날짜의 식사 루틴 항목 |
| GET | `/household/today?date=YYYY-MM-DD` | 가사 항목과 보유 가전 매칭 상태 |
| GET | `/health/today?date=YYYY-MM-DD` | 건강 루틴 항목 |
| GET | `/sleep/today?date=YYYY-MM-DD` | 수면 루틴 항목 |
| GET | `/thinq/devices` | ThinQ 조회 상태와 정규화된 보유 기기 목록 |

가이드 응답은 `date`, `category`, `items`를 반환합니다. 각 항목에는 `item_id`, `item_key`, `title`, `payload`, `status`, `completed_by`, `completed_at` 등이 있습니다. 저장된 `routine_items`를 읽으며 상세 조회만으로 새 추천을 생성하지 않습니다. 대상 날짜에 루틴이 없으면 404입니다.

건강 가이드의 허리·골반·다리·손목·전신 항목은 `payload.video`에 `pain_type`, `title`, `provider`, `youtube_id`, `url`을 포함합니다. 전신 운동처럼 제공된 경우 `duration`, `target`도 함께 반환합니다. 영상 정보는 `health_exercise_videos`의 활성 항목을 부위 코드와 매칭해 반환하며 Frontend는 `youtube_id`를 YouTube 개인정보 강화 임베드 주소에 사용합니다.

가사 가이드는 현재 보유한 세탁기·건조기, 로봇청소기, 식기세척기와 해당 활동을 매칭합니다. 매칭 결과는 응답에만 반영하고 저장된 루틴을 변경하지 않습니다. `appliance_connection_status`는 `connected`, `not_configured`, `auth_error`, `timeout`, `unsupported_country`, `error` 중 하나입니다. `/thinq/devices`의 각 기기는 `device_id`, `name`, `device_type`만 노출합니다. 서버의 단일 PAT는 설정된 아내 계정에만 사용하고 다른 계정에는 빈 기기 목록을 반환합니다. ThinQ 제어 API는 제공하지 않습니다.

## 챗봇과 식사 대체 메뉴

| 메서드 | 경로 | 요청·결과 |
| --- | --- | --- |
| GET | `/chat/messages?date=YYYY-MM-DD` | 해당 날짜의 대화 이력; 날짜 생략 시 KST 오늘 |
| POST | `/chat/messages` | `{"content":"...", "routine_item_id":null}`; LLM 답변과 대화 저장 |
| POST | `/chat/meal-alternative` | `{"routine_item_id":"...", "request":"다른 메뉴 보기"}`; 대체 메뉴 카드 1개 |

대화 메시지는 `role`, `content`, `created_at`, 선택적 `recommendation` 등을 반환합니다. `routine_item_id`를 주면 해당 식사 항목을 문맥으로 사용합니다. `meal-alternative`는 대화나 루틴을 저장하지 않습니다. 메뉴 선택은 `PUT /care/routine-items/{item_id}`로 별도 저장합니다. LLM 키가 없으면 채팅 API는 503을 반환합니다.

## 가족 공유

| 메서드 | 경로 | 요청·결과 |
| --- | --- | --- |
| GET · POST | `/family/household-requests` | 가사 요청 목록·생성. 생성 요청은 `target_date`, `reason`, `items`; 201 |
| GET | `/family/household-requests/{request_id}` | 요청과 항목별 진행 상태 |
| POST | `/family/household-requests/{request_id}/items/{item_id}/confirm` | 남편의 항목 확인 |
| POST | `/family/household-requests/{request_id}/items/{item_id}/complete` | 남편의 항목 완료 |
| GET | `/family/notifications` | 수신 알림 목록 |
| POST | `/family/notifications/{notification_id}/read` | 알림 읽음 처리 |
| GET | `/family/morning-reports/{target_date}` | 남편에게 허용된 아내의 오전 요약 |
| GET | `/family/motion/privacy` | 모션 동의·수집 설정 조회 |
| PUT · DELETE | `/family/motion/consent` | 동의 부여·철회 |
| PUT | `/family/motion/collection` | `enabled`가 boolean인 본문으로 신규 감지 수집 설정 |

오전 리포트는 프로필 원본이나 채팅 내용을 포함하지 않습니다. 모션 수집 OFF와 동의 철회는 기존 감지 기록을 삭제하지 않습니다.

## 모션

| 메서드 | 경로 | 결과 |
| --- | --- | --- |
| WS | `/movement/live/stream?token=<access_token>` | JPEG 바이너리 프레임 입력, 캘리브레이션·실시간 판정 메시지 |
| GET | `/movement/live` | 활성 단일 데모 세션의 누적 상태; 없으면 404 |
| GET | `/movement/events` | 로그인 사용자 또는 연결된 아내의 KST 오늘 감지 이벤트 |
| GET | `/movement/report/daily?date=YYYY-MM-DD` | 해당 날짜 감지 집계; 생략 시 KST 오늘 |

WebSocket은 브라우저 제약 때문에 Bearer 헤더 대신 `token` 쿼리와 허용된 `Origin`을 검사합니다. 동의가 없거나 수집 OFF이면 4003, 잘못된 Origin·토큰이면 1008, 저장소 오류이면 1011로 닫습니다. 서버는 `calibration_progress`, `calibration_done`, `frame` 메시지를 보냅니다. 일반 앱의 실시간 화면은 `/events`와 `/report/daily`를 조회하며 카메라 분석은 별도 진입점에서 사용합니다. `/movement/live`는 현재 단일 세션 데모 구현이므로 사용자별 세션 분리가 없습니다.

## 오늘 기록 초기화

`POST /care/today/reset`은 본문 없이 호출합니다. 성공하면 `{"target_date":"YYYY-MM-DD","reset":true}`를 반환합니다. 서버가 계산한 KST 오늘과 로그인한 아내 계정만 허용합니다.

DB의 `reset_daily_experience` 함수가 한 트랜잭션에서 오늘의 남편 알림, Daily 리포트, `posture_events`, 가사 요청과 `household_request_items`, 해당 루틴 항목과 연결된 채팅·피드백, `routine_items`, 같은 날짜의 모든 `daily_routines` revision, `daily_conditions`를 삭제합니다. 프로필, 배우자 연결, `motion_consents`, `posture_calibration_profiles`는 유지합니다. 루틴 항목과 무관한 일반 채팅 메시지도 유지합니다. 모션 이벤트는 `started_at`이 KST 오늘 구간에 속한 행만 삭제합니다. 프론트엔드는 성공 후 프로필 재입력 흐름으로 이동하지만 이 API는 DB 프로필 자체를 지우지 않습니다.

이 동작에는 [초기화 마이그레이션](../supabase/migrations/20260922000000_reset_daily_experience.sql), [오늘 모션 기록 추가 마이그레이션](../supabase/migrations/20260922010000_reset_today_posture_events.sql), [오늘 가족 요청·알림 추가 마이그레이션](../supabase/migrations/20260923000000_reset_today_family_requests.sql)이 필요합니다. 카메라 스트림이 계속 열려 있으면 초기화 직후 새로운 이벤트가 다시 기록될 수 있습니다. 적용·실행 순서는 [guide.md](../guide.md)를 참고하세요.
