# PLM Backend

## 병렬 개발용 도메인 Skeleton

Backend는 세 명이 독립적으로 작업할 수 있도록 `account`, `care`, `family` 경계로 나뉩니다. 각 도메인은 Pydantic Schema, FastAPI Router, Service Protocol, Repository Protocol, 메모리 Stub을 갖습니다. URL과 응답 Schema를 유지한 채 Stub Repository를 Supabase adapter로 교체할 수 있습니다.

| 도메인 | Prefix | 책임 |
|---|---|---|
| Account | `/api/v1/account` | Bootstrap, Profile 완료 상태, Partner 초대·연동 상태 |
| Care | `/api/v1/care` | 컨디션·예정 활동, 실행 기록, Daily report, Calendar |
| Family | `/api/v1/family` | 가사 요청, 남편 알림·오전 리포트, Motion 동의·수집 설정 |

상세 소유권과 교체 지점은 [DOMAIN_OWNERSHIP.md](DOMAIN_OWNERSHIP.md)를 확인합니다. 2026-09-18 기준 Account(파트너 연동)·Care·Family·Guide 도메인은 Supabase adapter로 교체됐고, Stub이 남은 곳은 `GET/PUT /account/profile`과 Chat뿐입니다(`docs/backend/API_IMPLEMENTATION_MATRIX.md`: implemented 43 / stub 4).

PLM Backend는 FastAPI 기반 서버입니다. 기본 상태 확인, Supabase Auth 토큰 검증, 임산부 프로필 6단계, 당일 컨디션·예정 활동, AI 하루 루틴 생성(룰 엔진 + RAG + OpenAI, 폴백 포함), 4종 가이드 조회, 실행 기록·Daily 리포트·캘린더, 가사 요청·남편 알림·오전 리포트, 파트너 초대/연동, 모션 인식(동의 게이트 포함) API를 제공합니다.

AI 루틴은 2026-09-18 실 DB 검증에서 `source=ai`로 생성을 확인했습니다. ThinQ 가전 제어는 Phase 2입니다. 화면별 Backend 연결 상태는 [docs/frontend/API_INTEGRATION_STATUS.md](../docs/frontend/API_INTEGRATION_STATUS.md), 요구사항 대비 검증 결과는 [docs/backend/REQUIREMENT_TRACEABILITY.md](../docs/backend/REQUIREMENT_TRACEABILITY.md)를 기준으로 합니다.

## 현재 구현 상태

### 기본 서버

- `GET /`: API 실행 상태
- `GET /health`: 프로세스 상태
- 로컬 Flutter Web 개발 origin을 위한 HTTP CORS
- 같은 origin 규칙을 적용한 모션 WebSocket handshake 검증

`/health`는 Supabase, MediaPipe 모델 또는 외부 서비스의 연결 상태까지 확인하지 않습니다.

### 임산부 프로필

- `GET /api/v1/profile/me`: 현재 사용자 프로필과 완료 단계 조회
- `PUT /api/v1/profile/me/due-date`: 1/6 출산예정일 또는 마지막 생리 시작일 저장
- `PUT /api/v1/profile/me/body`: 2/6 신장과 임신 전 체중 저장
- Supabase access token 검증
- 임신 주수·일수 및 연속 완료 단계 계산
- `pregnancy_profiles` migration과 RLS 활성화

- 3~6단계: `PUT /api/v1/profile/me/pregnancy-history`·`/pregnancy-count`·`/allergies`·`/medical-notes`(STEP 8, Supabase 실연결)

요청·응답 및 오류 계약은 [API 문서](../docs/api.md)와 [API_CONTRACT.md](../docs/backend/API_CONTRACT.md)를 기준으로 합니다.

### AI 하루 루틴 (W-ROUTINE-001/003)

- `GET /api/v1/routine/today`: 오늘(KST) 저장된 4종 가이드 조회. 없으면 404
- `POST /api/v1/routine/today`: 프로필 + 오늘 컨디션으로 루틴 생성·저장. AI 실패·10초 초과 시 전일 루틴 → 기본 템플릿 순으로 폴백해 항상 4종을 반환
- 파이프라인: `app/services/routine/` — ① `inputs.py` 입력 수집 → ② `rules.py`+`rules.yaml` 룰 엔진(16규칙) → ③ `retriever.py` RAG(OpenAI 임베딩 + RPC `match_pregnancy_knowledge`) → ④ `prompt.py` 프롬프트·JSON 스키마 → ⑤ `generator.py` OpenAI `json_schema strict` 호출 → ⑥ `service.py` 검증(금지 항목·`source_ids` 제거)·폴백 → ⑦ `repository.py` `daily_routines`/`routine_items` 저장
- 지식 적재(1회성)는 `tools/rag_ingest/`(팀원 패키지). 영문 공개자료 75청크 → 한국어 번역·재청크 → `text-embedding-3-small`(1536) → `pregnancy_knowledge`
- 설계·진행 기록: [웬즈데이 AI 파이프라인](../docs/ai_wednesday/Ai_wednesday_pipeline_v3.md), 테이블: `supabase/migrations/`

- **생성 완료 알림(2026-09-18)**: `POST /routine/today`가 성공하면 `FamilyService.notify_routine_ready`가 연동된 남편에게 알림을 보냅니다 — 하루 첫 생성은 `morning_report`(FUC-W-COND-002), 재생성은 `condition_changed` "아내의 루틴이 변경되었습니다."(FUC-W-COND-003). 남편 미연동이면 생략, 발송 실패해도 201을 유지합니다. 라우트(`app/api/v1/routine.py`)만 수정했고 `app/services/routine/**`는 그대로입니다

#### 상태 (2026-09-18)

| 항목 | 상태 |
| --- | --- |
| 코드 ①~⑦, API, `main.py` 등록 | 완료 |
| 단위 테스트 `tests/test_routine_*.py`(가짜 Supabase·OpenAI) | 통과 |
| Supabase 마이그레이션 적용 | 완료 (15건, 아래 "Supabase 준비" 참고) |
| 실DB 폴백 경로 | 완료 (2026-09-16) |
| **실호출 (`source=ai`)** | **완료 (2026-09-18, 실 DB에서 `source=ai` 생성 확인)** |
| 지식 적재 실행 (`--step all`) | 팀원 확인 필요 — 적재 여부는 `select count(*) from pregnancy_knowledge`로 확인 |

```sh
# 지식 적재 (tools/rag_ingest/.env에 OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
cd ../tools/rag_ingest && ../../backend/.venv/bin/python 02_translate_chunk_embed_upload.py --step all
# 완료 확인: select count(*) from pregnancy_knowledge  → 75 이상
```

### 당일 컨디션·가이드·실행 기록·리포트 (Care / Guide)

- `GET/PUT /api/v1/care/conditions/{date}`, `PUT .../activities`: 컨디션 7종·예정 활동(`daily_conditions`)
- `GET /api/v1/meals|household|health|sleep/today`: `routine_items` 읽기 전용 조회(AI 재호출 없음)
- `PUT /api/v1/care/routine-items/{id}/execution`: 실행 기록(`routine_items.status/completed_by`)
- `PUT /api/v1/care/routine-items/{id}`, `.../sleep-environment`: 메뉴 수락/거절/재요청·수면 환경 override를 `recommendation_feedback`에 이력으로 기록(2026-09-18). `routine_items` 원본은 읽기만
- `POST /api/v1/care/daily-reports/{date}/preview|finalize`, `GET .../{date}`: Daily 리포트(확정 시에만 `daily_reports` 1행). `family` 집계는 `household_requests` 실조회(2026-09-18)
- `GET /api/v1/care/calendar/{month}`: 저장 없이 `daily_conditions`+`daily_reports` 조합. **남편이 호출하면 `partner_links`로 연동된 아내 캘린더를 읽기 전용 반환**(2026-09-18, `app/api/v1/partner_scope.py`)

### 파트너 연동·가사 요청·알림 (Account / Family)

- `GET /api/v1/account/bootstrap`, `GET .../partner-link`, `POST .../partner-invitations`, `POST .../{token}/accept`: 초대 72시간·1회성, `partner_links`가 유일한 관계 SOURCE
- `POST/GET /api/v1/family/household-requests`, `GET .../{id}`, `POST .../confirm|complete`: 가사 요청 생성→남편 확인→완료(2026-09-18 Supabase 실연결)
- `GET /api/v1/family/notifications`, `POST .../{id}/read`: 남편 알림 3종 — 가사 요청 도착, 오전 리포트 도착, 루틴 변경(2026-09-18 실연결·발송 전부 구현)
- `GET /api/v1/family/morning-reports/{date}`: 남편 오전 리포트. 저장 없이 아내 테이블을 projection, 원본 점수 미노출
- `GET/PUT/DELETE /api/v1/family/motion/*`: 모션 동의·수집 ON/OFF(`motion_consents`)

### 모션 인식 데모

- `WS /api/v1/movement/live/stream`: JPEG 프레임 수신, 캘리브레이션 및 자세 판정
- `GET /api/v1/movement/live`: 활성 세션 누적 상태 조회
- `GET /api/v1/movement/events`: 감지 이벤트 조회
- `GET /api/v1/movement/report/daily`: 날짜별 이벤트 집계 및 부담 부위 요약
- MediaPipe Pose Landmarker, 규칙 엔진, 이벤트 기록과 리포트 생성
- 이벤트·캘리브레이션은 Supabase(`posture_events`, `posture_calibration_profiles`)에 저장됩니다(2026-09-16). 카메라 프레임·영상·landmark는 저장하지 않습니다(NFR-011)
- **동의 게이트(2026-09-18)**: `/live/stream`은 토큰 검증 뒤 `motion_consents`를 확인해 동의 없음·수집 OFF면 close code **4003**으로 거부합니다(origin/토큰 실패는 1008, 동의 조회 실패는 1011). 연결 시점 검사이므로 스트림 중 철회는 클라이언트가 WS를 끊습니다(NFR-012)
- **남편 조회(2026-09-18)**: `/events`, `/report/daily`는 호출자가 `partner_links`에 남편으로 있으면 아내 데이터를 읽기 전용 반환합니다(캘린더와 같은 `partner_scope` 규칙). `/live`는 제외
- 판정 임계값은 `services/movement/rules.yaml`의 데모값으로 **MVP 확정**(2026-09-18). 실서비스 값 재산정은 Phase 2

`/live`는 시연용 단일 세션 구조(`_current_session_id` 전역)라 다중 사용자 격리를 제공하지 않습니다.

## 미구현 영역 (2026-09-18 기준)

- `GET/PUT /account/profile`(6단계 통합 API) — `birth_date` 컬럼 미존재로 Stub. 단계별 API(`/profile/me/*`)는 실연결 완료
- 식사 재추천 챗봇(`/chat/messages`) — NFR-027 보관 정책 TBD, AI 담당 영역
- 컨디션 저장 → 루틴 재생성 자동화(현재는 프론트가 `PUT conditions` 뒤 `POST routine/today`를 따로 호출)
- ThinQ 가전 연동(Phase 2)
- NFR: 민감정보 컬럼 암호화(NFR-008), 백업·가용성·부하 측정, 운영 인증·권한·배포 정책

`LLMService`의 공급자 구현은 `services/routine/generator.py`의 `OpenAIRoutineGenerator`입니다. `MediaPipeService`는 확장 경계만 제공하며, 범용 `MediaPipeService.analyze_pose()`는 호출 시 `NotImplementedError`를 발생시킵니다. 실제 모션 데모는 별도 `services/movement/` 파이프라인을 사용합니다.

## 구조

```text
backend/
├── app/
│   ├── api/v1/
│   │   ├── account.py · care.py · chat.py · family.py · guide.py · profile.py · routine.py · movement.py
│   │   ├── partner_scope.py  # 남편→연동된 아내 데이터 치환(캘린더·모션 공용)
│   │   └── domain_errors.py
│   ├── domains/              # account · care · chat · family · guide — schemas · service · repository(Protocol) · stub_ · supabase_repository
│   ├── core/
│   ├── schemas/
│   ├── services/
│   │   ├── movement/
│   │   ├── routine/          # inputs · rules(.yaml) · retriever · prompt · generator · service · repository · fallback.yaml
│   │   ├── profile_service.py
│   │   ├── supabase_service.py
│   │   ├── llm_service.py
│   │   └── mediapipe_service.py
│   ├── utils/
│   └── main.py
├── models/pose_landmarker_full.task
├── tests/
├── requirements.txt
└── .env.example
```

## 설치 및 실행

요구사항:

- Python 3.11 이상
- MediaPipe wheel을 지원하는 OS 및 CPU 조합
- 프로필 API 사용 시 Supabase 프로젝트와 migration 적용

Windows PowerShell:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

macOS/Linux:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

실행 후 확인:

- API: <http://localhost:8000>
- Health: <http://localhost:8000/health>
- Swagger UI: <http://localhost:8000/docs>
- OpenAPI: <http://localhost:8000/openapi.json>

## 환경변수

```dotenv
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
LLM_API_KEY=
LLM_API_BASE_URL=
```

| 변수 | 현재 용도 |
| --- | --- |
| `SUPABASE_URL` | Supabase Auth 및 Database 주소 |
| `SUPABASE_ANON_KEY` | Backend에서는 현재 미사용. `Settings`에 선언만 되어 있고 참조하는 코드가 없습니다(Frontend 전용 공개 키). 사용자 access token 검증은 service role client의 `auth.get_user()`로 수행합니다 |
| `SUPABASE_SERVICE_ROLE_KEY` | 프로필·루틴·지식 테이블 서버 접근. 이 프로젝트는 service_role 기본 GRANT가 없어 `20260917000002_grant_service_role.sql` 적용이 필수 |
| `LLM_API_KEY` | **OpenAI API 키.** 루틴 생성(`gpt-4.1-mini`, `LLM_MODEL`로 변경 가능)과 검색 임베딩(`text-embedding-3-small`) 둘 다 이 키 |
| `LLM_API_BASE_URL` | 비우면 OpenAI SDK 기본 주소 |
| `LLM_MODEL` | 선택. 루틴 생성 모델명. 기본 `gpt-4.1-mini` |

프로필·루틴 API는 Supabase 설정이 없거나 연결할 수 없으면 `503`을 반환합니다. service role key와 LLM 키는 `backend/.env`에만 둡니다. `.env.example`에는 값을 넣지 않습니다(git 추적 파일). Frontend·Git·배포 산출물에 절대 내보내지 마세요(NFR-009).

## Supabase 준비

1. Supabase SQL Editor에서 `supabase/migrations/*.sql` **15건 전부**를 파일명(타임스탬프) 순서로 적용합니다. `20260917000002_grant_service_role.sql`을 빼면 service_role이 `42501 permission denied`를 받습니다. migration은 CLI로 자동 적용되지 않으므로 파일을 추가한 사람이 실제 프로젝트에도 반영해야 합니다.
2. `backend/.env`에 URL, service role key, OpenAI 키(`LLM_API_KEY`)를 입력합니다.
3. 로그인으로 발급받은 access token을 프로필 요청의 `Authorization: Bearer <token>`에 전달합니다.

현재 migration은 프로필 1~6단계 컬럼, `daily_conditions`, `daily_routines`, `routine_items`, `pregnancy_knowledge`(pgvector), 권한(6건, `20260915000000`~`20260917000002`)에 더해 STEP 7의 신규 테이블 9건(`profiles`, `partner_invitations`, `partner_links`, `household_requests`(+items), `daily_reports`, `notifications`, `motion_consents`, `chat_messages`, `recommendation_feedback`; `20260917010000`~`010800`)을 포함합니다.

**실 DB drift 확인(2026-09-18)**: 실서비스 프로젝트에 STEP 7 migration 9건이 미적용 상태였고, `daily_routines`에는 `unique (user_id, date)` 제약이 빠져 있어 `POST /routine/today`의 upsert가 `42P10`으로 실패했습니다. 둘 다 SQL Editor에서 수동 보정했습니다(`alter table public.daily_routines add constraint daily_routines_user_id_date_key unique (user_id, date);`). `create table if not exists`는 이미 있는 테이블의 제약을 고치지 않으므로, 새 환경에서 같은 증상이 나면 `information_schema`로 실제 컬럼·제약을 migration 파일과 대조하세요.

## 테스트

가상환경에 요구 패키지를 설치한 후 실행합니다.

```powershell
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -m unittest discover -s tests
```

테스트 150개(2026-09-18)는 기본 API, 프로필 6단계, 컨디션, 가이드 조회, 실행 기록·리포트·캘린더(남편 분기 포함), 파트너 연동, 가사 요청, 알림(루틴 생성 알림 포함), 오전 리포트, 모션 동의, AI 루틴(룰 엔진·스키마·폴백·저장·API), 모션 WebSocket(origin·토큰·동의 게이트·남편 조회)과 일일 리포트 집계를 다룹니다. 전부 가짜 Supabase·OpenAI·Pose extractor를 주입하므로 외부 키·카메라·네트워크가 필요하지 않습니다.

실 DB 수동 검증 절차(토큰 발급, 가사 요청→알림, 루틴 생성→오전 리포트 알림, 모션 동의 게이트)는 팀 노션의 "테스트 계정 토큰 발급"·"모션 인식 기능 테스트 방법" 페이지를 참고합니다.

## 개발 이력

날짜별 작업 내역입니다. 기준은 이 저장소의 커밋 로그이며, Backend 외 작업은 맥락 파악에 필요한 범위로만 적었습니다.

### 2026-09-14 (월) — 프로젝트 뼈대와 기획 문서

- 초기 Flutter Web + FastAPI 프로젝트 구조, 커밋 메시지 지침, `.vscode` 설정과 `guide.md`
- 모션 분석 모듈 이식: `app/services/movement/`의 `features.py`, `pose_extractor.py`, `rule_engine.py`, `rules.yaml`과 `models/pose_landmarker_full.task`
- PC 웹캠 검증 도구 `tools/motion_demo/` 추가
- `app/services/supabase_service.py`와 `tests/test_app.py` 추가. 이 시점의 Backend에는 기능 라우터가 없습니다
- 구현계획서에 누적 전방굴곡 위험 규칙 신규 문서화
- 기능요구사항명세서 원본 추가 후 아내(W)용 우선순위를 1~10으로 세분화하고, `docs/requirements`를 기획 문서 6종으로 교체

### 2026-09-15 (화) — Backend 기능 구현

- 남편(H)용 기능 우선순위 조정
- 모션 인식 API 구현: `app/api/v1/movement.py`, `app/schemas/movement.py`, `services/movement/`의 `session_manager.py`, `events.py`, `report.py`, `report_templates.yaml`, `calibration.py` 개편. 테스트는 `tests/test_movement_api.py`, `tests/test_report.py`
- 모션 인식 실시간 화면의 카메라 lifecycle 정리
- 임산부 프로필 1·2단계 구현: `app/api/v1/profile.py`, `app/schemas/profile.py`, `app/services/profile_service.py`, `app/utils/dates.py`. `app/core/security.py`에 Supabase access token 검증 추가
- 프로필 migration `supabase/migrations/20260915000000_create_pregnancy_profiles.sql` 작성 및 RLS 활성화. `tests/test_profile.py` 추가
- `docs/api.md`에 프로필 API 계약과 모션 WebSocket 프로토콜 반영
- Frontend/문서: `DESIGN.md`, `docs/screens/**` 화면 이미지, `AGENTS.md`, `docs/development/frontend_workflow.md` 추가. 루트 `README.md`와 이 문서 작성

### 2026-09-16 (수)

- Frontend에 디자인 시스템(`design_system/`), 라우팅(`routing/`), 화면 스켈레톤이 추가되었습니다. Backend 코드 변경은 없습니다
- W-PROFILE-001 출산예정일 규칙 완화: 입력 상한을 오늘 + 280일에서 **365일**로 늘리고, 마지막 생리 시작일을 선택 입력으로 명확히 했습니다. 출산예정일과 마지막 생리 시작일이 `+280일` 관계로 일치해야 하던 제약을 스키마와 DB에서 제거했습니다(`supabase/migrations/20260916000000_relax_due_date_constraint.sql`). 마지막 생리 시작일만 보내면 출산예정일은 여전히 자동 계산됩니다
- AI 하루 루틴(W-ROUTINE-001/003) 파이프라인 구현. 결정 사항: 판단 LLM·임베딩 모두 **OpenAI 단일**(Claude 결정 철회, `anthropic` 의존성 없음), 룰은 `rules.yaml`(모션 파트 방식), 카테고리명 `household`, LLM 출력은 `routine_items.payload` 모양과 동일
- 팀원 RAG 패키지를 `tools/rag_ingest/`로 편입(영문 공개자료 75청크, `text-embedding-3-small` 1536). 자체 PDF·Voyage 계획은 폐기
- 마이그레이션 3건 추가: `20260917000000_pregnancy_knowledge.sql`(pgvector·RPC), `20260917000001_routine_tables.sql`(프로필 3~6단계 컬럼·컨디션·루틴·항목), `20260917000002_grant_service_role.sql`. Supabase에 5건 전부 적용 확인
- `.env.example`에 실제 값이 들어간 것을 발견해 placeholder로 원복
- 실DB 폴백 경로 검증 완료(OpenAI 429 → `fallback_template` 저장 → 재생성 덮어쓰기 → 테스트 행 삭제)
- Backend 테스트 37개 전부 통과합니다
- AI 루틴 남은 작업은 OpenAI 크레딧 충전 후 실테스트 2건(지식 적재, 루틴 실호출)

### 2026-09-17 (목) — 요구사항 재감사와 도메인 실연결 (STEP 0~14)

- 최신 요구사항 대비 화면 단위 재감사(`docs/backend/BACKEND_STATUS.md`), 데이터 소유권·목표 스키마·47개 API 계약 문서화, 신규 migration 9건 작성(`20260917010000`~`010800`)
- 프로필 3~6단계, 컨디션, 가이드 조회 4종, 실행 기록·Daily 리포트·캘린더, 남편 오전 리포트, 파트너 초대/연동, 모션 동의를 Supabase 실연결. 상세는 `docs/backend/API_IMPLEMENTATION_MATRIX.md`

### 2026-09-18 (금) — 현재

- (새벽) Frontend Repository 패턴 도입·최종 검증(STEP 15~16, `docs/backend/REQUIREMENT_TRACEABILITY.md`)
- **가사 요청·알림 Supabase 실연결**(`app/domains/family/supabase_repository.py`): 생성→확인→완료 전이, 부부 외 403, 상태 오류 409. 목록 라우트 2개의 저장소 장애 503 처리 보강
- **Daily 리포트 `family` 집계**를 하드코딩 0에서 `household_requests` 실조회(누적 funnel)로 교체
- **남편 캘린더**: `partner_links` 연동 시 아내 캘린더 읽기 전용, 미연동은 본인(빈) 캘린더
- **루틴 생성 완료 알림**: `POST /routine/today` 성공 직후 첫 생성 `morning_report` / 재생성 `condition_changed` 발송(FUC-W-COND-002/003). `routine.py` 라우트만 수정(커밋 `3d1bb72`, Routine 담당 리뷰 대상)
- **routine-item 피드백 실연결**: 메뉴 수락/거절/재요청·수면 환경 override → `recommendation_feedback`(implemented 43 / stub 4)
- **Motion**: `/live/stream` 동의 게이트(4003/1011), `/events`·`/report/daily` 남편 조회 분기(`api/v1/partner_scope.py`로 캘린더 헬퍼 공용화), `rules.yaml` 데모값 MVP 확정. `services/movement/**`·`services/routine/**` 미수정
- **실 DB drift 발견·보정**: STEP 7 migration 9건 미적용, `daily_routines` unique 제약 누락(42P10) → SQL Editor 수동 적용. 아래 "Supabase 준비" 참고
- 실 DB에서 AI 루틴 `source=ai` 생성 확인. 아내/남편/제3자 테스트 계정으로 가사 요청→알림, 루틴 생성→오전 리포트 알림, 캘린더·모션 남편 조회, 동의 게이트 수동 검증
- 문서 갱신: `API_IMPLEMENTATION_MATRIX`(implemented 41 / stub 6), `API_CONTRACT`, `BACKEND_STATUS`, `REQUIREMENT_TRACEABILITY`(READY 12 / PARTIAL 1 / BLOCKED 1), `DATA_OWNERSHIP`, `frontend/API_INTEGRATION_STATUS`, `docs/api.md`, `docs/movement/구현계획서_v3.md`
- Backend 테스트 150개 전부 통과
- 남은 작업: `routine.py` 훅 리뷰, Chat 저장 계층(경계 확인 후), `account/profile` 통합 API(`birth_date` migration), 메뉴 수락·수면 override 실연결, 기획 대기 3건(H-INVITE-001 흐름, H-REQUEST-002, Calendar 지수식)과 컨디션 변경 알림 문서 충돌(`03_유스케이스명세서` 구판) 정리

## 관련 문서

- [전체 프로젝트 README](../README.md)
- [API 계약](../docs/api.md)
- [Architecture](../docs/architecture.md)
- [Supabase](../supabase/README.md)
- [웬즈데이 AI 파이프라인](../docs/ai_wednesday/Ai_wednesday_pipeline_v3.md)
- [모션 통합 및 검증](../docs/movement/README.md)
- [Backend 구현 상태](../docs/backend/BACKEND_STATUS.md) · [API 매트릭스](../docs/backend/API_IMPLEMENTATION_MATRIX.md) · [요구사항 추적](../docs/backend/REQUIREMENT_TRACEABILITY.md)
- [Frontend API 연결 상태](../docs/frontend/API_INTEGRATION_STATUS.md)
