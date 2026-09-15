# PLM
LG DX 임산부 일상 루틴 모드 

## Tech Stack

- Flutter Web (Material 3)
- FastAPI (Python 3.11+)
- Supabase (Auth / PostgreSQL Database / Storage)
- MediaPipe
- External LLM API
- Git / GitHub, VSCode

## Project Structure

```text
PLM/
├── frontend/
│   ├── lib/
│   │   ├── core/{config,constants,network,utils}/
│   │   ├── models/
│   │   ├── services/
│   │   ├── features/{profile,condition,routine,meal,movement,sleep}/
│   │   ├── widgets/
│   │   ├── app.dart
│   │   └── main.dart
│   ├── assets/
│   ├── test/
│   ├── web/
│   ├── pubspec.yaml
│   ├── pubspec.lock
│   └── .env.example
├── backend/
│   ├── app/
│   │   ├── api/v1/
│   │   ├── core/{config.py,security.py}
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/{supabase_service.py,llm_service.py,mediapipe_service.py}
│   │   ├── utils/
│   │   └── main.py
│   ├── tests/
│   ├── requirements.txt
│   └── .env.example
├── supabase/
│   ├── migrations/
│   └── README.md
├── docs/{architecture.md,api.md}
├── .vscode/{settings.json,extensions.json}
├── .gitignore
├── .env.example
└── README.md
```

`frontend/lib/core`에는 공통 설정, 상수, HTTP 통신, 유틸리티를 둡니다.
`models`, `services`, `widgets`는 프론트엔드 공통 구성이고 `features`는 기능별 개발 영역입니다.
`main.dart`는 초기화와 앱 실행, `app.dart`는 앱 테마와 초기 화면을 담당합니다.
상태관리 라이브러리는 기능 개발 시 팀에서 선택합니다.

`backend/app/api/v1`에는 향후 API 라우터를, `core`에는 설정과 인증 코드를 둡니다.
`models`, `schemas`, `services`, `utils`는 각각 모델, 요청/응답 스키마, 외부 서비스 연동, 유틸리티 영역입니다.
`tests`는 테스트, `supabase/migrations`는 향후 DB 변경 이력, `docs`는 설계와 API 문서입니다.
빈 디렉터리는 `.gitkeep` 또는 `__init__.py`로 Git clone 후에도 유지됩니다.

## Requirements

- Flutter stable, Dart (Flutter SDK에 포함)
- 이 초기 프로젝트의 Dart 요구사항: 3.12.2 이상, 4.0 미만
- Python 3.11+ (MediaPipe wheel이 제공되는 OS/CPU 조합 필요)
- Git
- Chrome (Flutter Web 실행)

현재 검증 환경은 Flutter 3.44.4 / Dart 3.12.2입니다.

## Initial Setup

Cursor / VS Code에서 `main()` 위 실행 버튼과 기기 선택을 사용하는 방법은
[개발 환경 및 실행 안내](guide.md)를 참고하세요. 루트 `.vscode/launch.json`은
Chrome 실행과 선택한 기기 실행을 제공합니다. 공통 편집기 설정과 실행 항목은 저장소에서 공유하고,
SDK 경로는 각자의 편집기 사용자 설정 또는 PATH에 지정합니다. 팀의 Flutter 버전은 동일하게 맞추는 것을 권장합니다.

저장소를 clone한 후 루트에서 시작합니다. 프론트엔드와 백엔드는 별도 터미널로 실행합니다.
환경변수가 비어 있어도 초기 PLM 화면과 백엔드 상태 확인은 실행됩니다.
Supabase 연결을 사용할 때 프론트엔드에 URL과 anon key를 함께 입력합니다.

### Frontend

```sh
cd frontend
flutter pub get
cp .env.example .env
# .env의 공개 설정 입력
flutter run -d chrome
```

Windows PowerShell에서 파일 복사는 `Copy-Item .env.example .env`를 사용해도 됩니다.
`.env`는 Flutter asset이므로 실행/빌드 전에 존재해야 합니다.

### Backend

Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
# .env 설정 입력
python -m uvicorn app.main:app --reload
```

Windows cmd에서는 `.venv\Scripts\activate.bat`으로 활성화합니다.
PowerShell에서 활성화가 제한되면 `.venv\Scripts\python.exe -m pip install -r requirements.txt`와
`.venv\Scripts\python.exe -m uvicorn app.main:app --reload`로 직접 실행할 수 있습니다.

macOS/Linux:

```sh
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env 설정 입력
uvicorn app.main:app --reload
```

API: http://localhost:8000

Swagger: http://localhost:8000/docs

설치된 Python의 `venv` 생성이 `ensurepip`에서 실패하면 Python 설치를 복구하거나,
시스템 pip가 있는 경우 루트에서 아래 명령으로 생성된 가상환경에 pip를 설치합니다.

```powershell
py -m pip --python backend/.venv/Scripts/python.exe install pip -r backend/requirements.txt
```

## Environment Variables

| 변수 | 용도 | 위치 |
| --- | --- | --- |
| SUPABASE_URL | Supabase 프로젝트 URL | frontend / backend |
| SUPABASE_ANON_KEY | 브라우저용 공개 anon key | frontend / backend |
| SUPABASE_SERVICE_ROLE_KEY | 서버용 권한 키 | backend 전용 |
| LLM_API_KEY | 향후 외부 LLM 인증 키 | backend 전용 |
| LLM_API_BASE_URL | 향후 LLM API 기본 주소 | backend 전용 |
| BACKEND_URL | FastAPI 주소, 기본 `http://localhost:8000` | frontend |

루트 `.env.example`은 전체 항목의 참고 목록입니다. 앱은 각자 `frontend/.env`, `backend/.env`를 사용하며
루트 `.env`를 읽지 않습니다. Backend 환경변수는 `Settings`를 통해 접근합니다.
실제 `.env` 파일은 Git에서 제외하고 `.env.example`은 공유합니다.
Flutter Web asset은 브라우저에 공개되므로 frontend에는 service role key나 LLM API key를 넣지 않습니다.
Supabase 데이터 접근 정책(RLS)은 DB 스키마 설계 시 함께 정의합니다.

## Git Convention

커밋 메시지의 제목과 본문은 항상 한글로 작성합니다.
코드 식별자, 파일명, 라이브러리명 등 기술 명칭은 원문을 유지할 수 있습니다.
예: `초기 프로젝트 구조 및 개발 환경 설정 추가`

- `main`: 팀에서 검증한 안정 버전
- `develop`: 기능을 통합하는 개발 브랜치
- `feature/*`: 기능별 작업 브랜치 (예: `feature/profile`)

`develop`에서 기능 브랜치를 만들고 PR로 통합한 뒤, 검증된 변경을 `main`에 반영합니다.
브랜치 생성 및 보호 규칙은 GitHub에서 팀이 설정합니다.
Flutter 앱의 `pubspec.lock`은 Git에 포함해 같은 의존성 버전을 공유합니다.

## Validation

```sh
cd frontend
flutter analyze
flutter build web
```

백엔드 가상환경에서:

```sh
cd backend
python -m pip check
python -m unittest discover -s tests
```

## Current Scope

첨부 모션 데모의 분석 모듈과 모델은 `backend/app/services/movement/`, `backend/models/`에 배치했습니다.
PC 웹캠 테스트 도구는 `tools/motion_demo/`에서 별도로 실행합니다.
원본 파일 이동 목록과 설치/테스트 명령은 [모션 통합 문서](docs/movement/README.md)를 참고하세요.
백엔드 쪽 실시간 분석 API(`WS /api/v1/movement/live/stream`, `GET /live`, `GET /events`, `GET /report/daily`)는
전부 실제로 동작합니다: 브라우저가 JPEG 프레임을 WebSocket으로 보내면 백엔드의 기존 MediaPipe·규칙 엔진
파이프라인이 처리해 캘리브레이션→실시간 판정→이벤트 기록→일일 리포트까지 수행하고, 결과를 다시
브라우저로 돌려줍니다(테스트는 가짜 카메라 입력으로 검증, `backend/tests/test_movement_api.py`,
`backend/tests/test_report.py`). 카메라 처리에 필요한 `mediapipe`/`PyYAML`이 `backend/requirements.txt`
기본 요구사항에 포함되어 있으니 위 Backend 설치 절차만 그대로 따르면 됩니다(별도 설치 불필요).
Flutter Web 쪽 카메라 캡처/전송 클라이언트(B-4, `frontend/lib/features/movement/`)도 구현했고
`app.dart`의 "모션 인식 데모 보기" 버튼으로 접근할 수 있습니다. 다만 카메라/WebSocket 저수준 호출은
`dart:html` 기반이라 이 저장소 환경(카메라 없음)에서는 자동 검증이 안 되고, **실제 브라우저에서의
카메라 권한·캘리브레이션·실시간 오버레이 동작은 아직 사람이 직접 확인해야 합니다**
(`flutter run -d chrome`, 상세는 `frontend/lib/features/movement/README.md`).
이 WebSocket 연동은 데모 속도를 위한 결정이며, 실서비스에서는 온디바이스 프라이버시 원칙 복원을 위해
클라이언트 사이드 추론 전환을 재검토해야 합니다. 상세 근거는 [구현계획서 v3 §4](docs/movement/구현계획서_v3.md)를 참고하세요.

초기 화면, 환경 설정, API 상태 확인, 로컬 CORS, Supabase client 생성 경계만 준비되어 있습니다.
프로필/컨디션/루틴/식단/움직임/수면 기능, 상태관리, 인증/토큰 검증, DB 스키마 및 migration,
Storage 작업, LLM 실제 호출, 제품 화면의 MediaPipe 연동은 구현하지 않았습니다.
LLM은 추상 인터페이스이며 기존 API용 MediaPipe 서비스 메서드는 호출 시 `NotImplementedError`를 발생시킵니다.
독립 모션 분석 모듈과 PC 웹캠 도구는 이 API용 확장 지점과 별도로 제공됩니다.
