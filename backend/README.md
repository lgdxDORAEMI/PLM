# PLM Backend

## 병렬 개발용 도메인 Skeleton

Backend는 세 명이 독립적으로 작업할 수 있도록 `account`, `care`, `family` 경계로 나뉩니다. 각 도메인은 Pydantic Schema, FastAPI Router, Service Protocol, Repository Protocol, 메모리 Stub을 갖습니다. URL과 응답 Schema를 유지한 채 Stub Repository를 Supabase adapter로 교체할 수 있습니다.

| 도메인 | Prefix | 책임 |
|---|---|---|
| Account | `/api/v1/account` | Bootstrap, Profile 완료 상태, Partner 초대·연동 상태 |
| Care | `/api/v1/care` | 컨디션·예정 활동, 실행 기록, Daily report, Calendar |
| Family | `/api/v1/family` | 가사 요청, 남편 알림·오전 리포트, Motion 동의·수집 설정 |

상세 소유권과 교체 지점은 [DOMAIN_OWNERSHIP.md](DOMAIN_OWNERSHIP.md)를 확인합니다. 현재 Stub 데이터는 프로세스 재시작 시 초기화되며 Supabase migration은 추가하지 않았습니다.

PLM Backend는 FastAPI 기반 서버입니다. 현재 기본 상태 확인, Supabase Auth 토큰 검증을 사용하는 임산부 프로필 1·2단계, AI 하루 루틴 생성(룰 엔진 + RAG + OpenAI, 폴백 포함), 그리고 단일 사용자 모션 인식 데모 API를 제공합니다.

AI 루틴은 코드·DB·단위 테스트까지 완료됐고 **OpenAI 크레딧 충전 후 실호출 테스트(지식 적재 1회 + 루틴 생성 1회)만 남았습니다.** 배우자 연동과 ThinQ 가전 제어는 아직 구현되지 않았습니다. Frontend UI 개발 중에는 이 Backend를 확장하지 않고 Mock Service를 사용합니다.

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

프로필 3~6단계와 해당 Frontend 화면은 아직 구현되지 않았습니다. 요청·응답 및 오류 계약은 [API 문서](../docs/api.md)를 기준으로 합니다.

### AI 하루 루틴 (W-ROUTINE-001/003)

- `GET /api/v1/routine/today`: 오늘(KST) 저장된 4종 가이드 조회. 없으면 404
- `POST /api/v1/routine/today`: 프로필 + 오늘 컨디션으로 루틴 생성·저장. AI 실패·10초 초과 시 전일 루틴 → 기본 템플릿 순으로 폴백해 항상 4종을 반환
- 파이프라인: `app/services/routine/` — ① `inputs.py` 입력 수집 → ② `rules.py`+`rules.yaml` 룰 엔진(16규칙) → ③ `retriever.py` RAG(OpenAI 임베딩 + RPC `match_pregnancy_knowledge`) → ④ `prompt.py` 프롬프트·JSON 스키마 → ⑤ `generator.py` OpenAI `json_schema strict` 호출 → ⑥ `service.py` 검증(금지 항목·`source_ids` 제거)·폴백 → ⑦ `repository.py` `daily_routines`/`routine_items` 저장
- 지식 적재(1회성)는 `tools/rag_ingest/`(팀원 패키지). 영문 공개자료 75청크 → 한국어 번역·재청크 → `text-embedding-3-small`(1536) → `pregnancy_knowledge`
- 설계·진행 기록: [AI 루틴 파이프라인](../docs/ai_routine/AI_루틴_파이프라인.md), 테이블: [DB ERD](../docs/DB_ERD_스키마.md)

#### 상태 (2026-09-16)

| 항목 | 상태 |
| --- | --- |
| 코드 ①~⑦, API, `main.py` 등록 | 완료 |
| 단위 테스트 `tests/test_routine_*.py` 14개(가짜 Supabase·OpenAI) | 통과 |
| Supabase 마이그레이션 5건 적용 (`20260917000000`~`000002`) | 완료. 5테이블·RPC 접근 확인 |
| 실DB 폴백 경로(테스트 사용자로 삽입→생성→검증→삭제) | 완료. `source=fallback_template`, 항목 7행, 재생성 덮어쓰기 확인 |
| **지식 적재 실행 (`--step all`)** | **미실행 — OpenAI 크레딧 0 (`insufficient_quota`)** |
| **실호출 1회 (`source=ai`, `source_ids` 채워짐)** | **미실행 — 같은 이유** |

크레딧 충전 후 남은 작업은 위 2건만입니다. 견적: 적재 약 $0.06, 루틴 1회 약 $0.005~0.009(`gpt-4.1-mini` 기준 입력 16k·출력 1.2k 토큰). $5 충전이면 적재 + 500회 이상.

```sh
# 1) 지식 적재 (tools/rag_ingest/.env에 OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
cd ../tools/rag_ingest && ../../backend/.venv/bin/python 02_translate_chunk_embed_upload.py --step all
# 완료 확인: select count(*) from pregnancy_knowledge  → 75 이상
# 2) 실호출: 로그인 토큰으로 POST /api/v1/routine/today → source=ai, source_ids 비어있지 않음, 응답 10초 이내
```

### 모션 인식 데모

- `WS /api/v1/movement/live/stream`: JPEG 프레임 수신, 캘리브레이션 및 자세 판정
- `GET /api/v1/movement/live`: 활성 세션 누적 상태 조회
- `GET /api/v1/movement/events`: 감지 이벤트 조회
- `GET /api/v1/movement/report/daily`: 날짜별 이벤트 집계 및 부담 부위 요약
- MediaPipe Pose Landmarker, 규칙 엔진, 이벤트 기록과 리포트 생성

이 API는 시연을 위한 단일 세션 구조입니다. 사용자 ID는 데모 값이며 이벤트는 메모리에, 캘리브레이션은 `backend/.local/`에 저장됩니다. 서버 재시작 시 이벤트가 사라지고 다중 사용자 격리도 제공하지 않으므로 운영 구조로 사용하면 안 됩니다.

## 미구현 영역

- 프로필 3~6단계 API (DB 컬럼은 `20260917000001` migration에 추가됨)
- 당일 컨디션 입력 API (`daily_conditions` 테이블은 있음, 라우터 없음 — 루틴 생성의 선행 조건)
- AI 루틴 실호출 검증(크레딧 충전 대기), 식사 재추천 챗봇
- 배우자 초대, 공유, 요청과 알림 API
- 루틴 실행 기록과 제품용 Daily 리포트
- ThinQ 가전 연동
- 모션 이벤트·캘리브레이션의 Supabase 영속화
- 운영 인증·권한·배포 정책

`LLMService`의 공급자 구현은 `services/routine/generator.py`의 `OpenAIRoutineGenerator`입니다. `MediaPipeService`는 확장 경계만 제공하며, 범용 `MediaPipeService.analyze_pose()`는 호출 시 `NotImplementedError`를 발생시킵니다. 실제 모션 데모는 별도 `services/movement/` 파이프라인을 사용합니다.

## 구조

```text
backend/
├── app/
│   ├── api/v1/
│   │   ├── profile.py
│   │   ├── routine.py
│   │   └── movement.py
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

1. Supabase SQL Editor에서 `supabase/migrations/*.sql` 5건을 파일명 순서로 적용합니다. 마지막 `20260917000002_grant_service_role.sql`을 빼면 service_role이 `42501 permission denied`를 받습니다.
2. `backend/.env`에 URL, service role key, OpenAI 키(`LLM_API_KEY`)를 입력합니다.
3. 로그인으로 발급받은 access token을 프로필 요청의 `Authorization: Bearer <token>`에 전달합니다.

현재 migration은 프로필 1~6단계 컬럼, `daily_conditions`, `daily_routines`, `routine_items`, `pregnancy_knowledge`(pgvector)와 권한을 포함합니다. 모션 관련 테이블은 [Supabase 설계 메모](../supabase/README.md)에만 있으며 실제 migration은 없습니다.

## 테스트

가상환경에 요구 패키지를 설치한 후 실행합니다.

```powershell
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -m unittest discover -s tests
```

테스트 37개는 기본 API, 프로필 검증·인증·저장 경계, AI 루틴(룰 엔진·스키마·폴백·저장·API), 모션 WebSocket 프로토콜, origin 차단과 일일 리포트 집계를 다룹니다. 루틴 테스트는 가짜 Supabase·OpenAI를 주입하므로 외부 키가 필요하지 않습니다. 모션 API 테스트는 가짜 Pose extractor를 주입하므로 실제 카메라가 필요하지 않습니다.

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

### 2026-09-16 (수) — 현재

- Frontend에 디자인 시스템(`design_system/`), 라우팅(`routing/`), 화면 스켈레톤이 추가되었습니다. Backend 코드 변경은 없습니다
- W-PROFILE-001 출산예정일 규칙 완화: 입력 상한을 오늘 + 280일에서 **365일**로 늘리고, 마지막 생리 시작일을 선택 입력으로 명확히 했습니다. 출산예정일과 마지막 생리 시작일이 `+280일` 관계로 일치해야 하던 제약을 스키마와 DB에서 제거했습니다(`supabase/migrations/20260916000000_relax_due_date_constraint.sql`). 마지막 생리 시작일만 보내면 출산예정일은 여전히 자동 계산됩니다
- AI 하루 루틴(W-ROUTINE-001/003) 파이프라인 구현. 결정 사항: 판단 LLM·임베딩 모두 **OpenAI 단일**(Claude 결정 철회, `anthropic` 의존성 없음), 룰은 `rules.yaml`(모션 파트 방식), 카테고리명 `household`, LLM 출력은 `routine_items.payload` 모양과 동일
- 팀원 RAG 패키지를 `tools/rag_ingest/`로 편입(영문 공개자료 75청크, `text-embedding-3-small` 1536). 자체 PDF·Voyage 계획은 폐기
- 마이그레이션 3건 추가: `20260917000000_pregnancy_knowledge.sql`(pgvector·RPC), `20260917000001_routine_tables.sql`(프로필 3~6단계 컬럼·컨디션·루틴·항목), `20260917000002_grant_service_role.sql`. Supabase에 5건 전부 적용 확인
- `.env.example`에 실제 값이 들어간 것을 발견해 placeholder로 원복
- 실DB 폴백 경로 검증 완료(OpenAI 429 → `fallback_template` 저장 → 재생성 덮어쓰기 → 테스트 행 삭제)
- Backend 테스트 37개 전부 통과합니다
- **AI 루틴 남은 작업: OpenAI 크레딧 충전 후 실테스트 2건(지식 적재, 루틴 실호출)만.** 그 외 다음 작업은 `docs/04_3_개발순서.md`의 W-COND-001 컨디션 입력 API(테이블은 이미 있음)

## 관련 문서

- [전체 프로젝트 README](../README.md)
- [API 계약](../docs/api.md)
- [Architecture](../docs/architecture.md)
- [Supabase](../supabase/README.md)
- [AI 루틴 파이프라인](../docs/ai_routine/AI_루틴_파이프라인.md)
- [DB ERD 스키마](../docs/DB_ERD_스키마.md)
- [모션 통합 및 검증](../docs/movement/README.md)
