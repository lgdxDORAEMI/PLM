# PLM Backend

PLM Backend는 FastAPI 기반 서버입니다. 현재 기본 상태 확인, Supabase Auth 토큰 검증을 사용하는 임산부 프로필 1·2단계, 그리고 단일 사용자 모션 인식 데모 API를 제공합니다.

식사·가사·건강·수면 루틴 생성, 배우자 연동, 실제 LLM 호출과 ThinQ 가전 제어는 아직 구현되지 않았습니다. Frontend UI 개발 중에는 이 Backend를 확장하지 않고 Mock Service를 사용합니다.

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

### 모션 인식 데모

- `WS /api/v1/movement/live/stream`: JPEG 프레임 수신, 캘리브레이션 및 자세 판정
- `GET /api/v1/movement/live`: 활성 세션 누적 상태 조회
- `GET /api/v1/movement/events`: 감지 이벤트 조회
- `GET /api/v1/movement/report/daily`: 날짜별 이벤트 집계 및 부담 부위 요약
- MediaPipe Pose Landmarker, 규칙 엔진, 이벤트 기록과 리포트 생성

이 API는 시연을 위한 단일 세션 구조입니다. 사용자 ID는 데모 값이며 이벤트는 메모리에, 캘리브레이션은 `backend/.local/`에 저장됩니다. 서버 재시작 시 이벤트가 사라지고 다중 사용자 격리도 제공하지 않으므로 운영 구조로 사용하면 안 됩니다.

## 미구현 영역

- 프로필 3~6단계
- AI 하루 루틴 및 식사 재추천
- 실제 LLM 공급자 연동
- 배우자 초대, 공유, 요청과 알림 API
- 루틴 실행 기록과 제품용 Daily 리포트
- ThinQ 가전 연동
- 모션 이벤트·캘리브레이션의 Supabase 영속화
- 운영 인증·권한·배포 정책

`LLMService`와 `MediaPipeService`는 확장 경계만 제공합니다. `LLMService`의 공급자 구현은 없고, 범용 `MediaPipeService.analyze_pose()`는 호출 시 `NotImplementedError`를 발생시킵니다. 실제 모션 데모는 별도 `services/movement/` 파이프라인을 사용합니다.

## 구조

```text
backend/
├── app/
│   ├── api/v1/
│   │   ├── profile.py
│   │   └── movement.py
│   ├── core/
│   ├── schemas/
│   ├── services/
│   │   ├── movement/
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
| `SUPABASE_ANON_KEY` | 사용자 access token 검증용 client 구성 |
| `SUPABASE_SERVICE_ROLE_KEY` | 프로필 테이블 서버 접근 |
| `LLM_API_KEY` | 향후 LLM 공급자 인증용, 현재 미사용 |
| `LLM_API_BASE_URL` | 향후 LLM API 주소, 현재 미사용 |

프로필 API는 Supabase 설정이 없거나 연결할 수 없으면 `503`을 반환합니다. service role key는 RLS를 우회하므로 Frontend 또는 Git에 노출하지 마세요.

## Supabase 준비

1. Supabase 프로젝트에 [프로필 migration](../supabase/migrations/20260915000000_create_pregnancy_profiles.sql)을 적용합니다.
2. `backend/.env`에 URL, anon key, service role key를 입력합니다.
3. 로그인으로 발급받은 access token을 프로필 요청의 `Authorization: Bearer <token>`에 전달합니다.

현재 migration은 프로필 1·2단계만 포함합니다. 모션 관련 테이블은 [Supabase 설계 메모](../supabase/README.md)에만 있으며 실제 migration은 없습니다.

## 테스트

가상환경에 요구 패키지를 설치한 후 실행합니다.

```powershell
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -m unittest discover -s tests
```

테스트는 기본 API, 프로필 검증·인증·저장 경계, 모션 WebSocket 프로토콜, origin 차단과 일일 리포트 집계를 다룹니다. 모션 API 테스트는 가짜 Pose extractor를 주입하므로 실제 카메라가 필요하지 않습니다.

## 관련 문서

- [전체 프로젝트 README](../README.md)
- [API 계약](../docs/api.md)
- [Architecture](../docs/architecture.md)
- [Supabase](../supabase/README.md)
- [모션 통합 및 검증](../docs/movement/README.md)
