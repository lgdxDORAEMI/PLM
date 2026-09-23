# 개발 환경 및 실행 안내

## ThinQ Connect 설정과 확인

Backend의 `backend/.env`에 `THINQ_PAT=<Personal Access Token>`, `THINQ_COUNTRY_CODE=KR`, `THINQ_CLIENT_ID=<고정 UUID>`를 설정한다. `THINQ_CLIENT_ID`는 한 번 생성해 유지하고 요청마다 새로 만들지 않는다. 실제 PAT는 코드·문서·Frontend `.env`·GitHub Actions에 저장하지 않는다. Railway 배포 시 Backend 서비스 Variable을 사용한다. ThinQ 설정 변경 후 Backend를 재시작한다.

실제 확인 순서: ① Backend 재시작 ② `PLM_WIFE_EMAIL`과 일치하는 아내 계정의 Supabase 로그인 토큰으로 `GET /api/v1/thinq/devices` 조회 ③ `status=connected`와 등록 가전 확인 ④ 오늘 컨디션 입력 및 AI 루틴 생성 ⑤ 가사 가이드 진입 ⑥ `3. 가전이 대신합니다`에서 보유 가전으로 가능한 일만 표시되는지 확인. `connected`에 빈 목록이면 등록 기기가 없거나 해당 PAT의 계정이 다르다. `not_configured`면 PAT·UUID 또는 로그인 계정 설정을, `auth_error`면 PAT 유효성을, `timeout`·`error`면 ThinQ 접속 상태를 확인한다. 오류 시 가전 추천은 비고 일반 가사는 계속 표시된다. 단일 PAT의 목록은 설정된 아내 계정에만 제공한다. 실제 기기 제어는 구현하지 않았다.


## 팀 공통 설정과 개인 SDK 경로

저장소의 `.vscode/settings.json`, `extensions.json`, `launch.json`에는 공통 편집기 설정, 권장 확장, 실행 항목을 공유합니다. SDK 설치 경로는 각자의 편집기 사용자 설정에 저장합니다. 작업 영역 설정에 개인 경로를 넣으면 다른 팀원의 사용자 설정보다 우선하므로 저장소에는 `dart.flutterSdkPath`를 추가하지 않습니다.

각 팀원은 `Ctrl+Shift+P` → `Preferences: Open User Settings (JSON)`을 열고 기존 JSON 객체에 다음 항목을 추가합니다. 경로는 본인의 Flutter SDK 루트로 바꾸고 `bin`은 붙이지 않습니다. 이 파일은 저장소 밖의 개인 편집기 설정입니다.

```json
{
  "dart.flutterSdkPath": "C:/dev/flutter"
}
```

Windows에서는 `C:/development/flutter`, macOS/Linux에서는 `/Users/사용자명/development/flutter`처럼 각 작업자의 실제 설치 경로를 사용자 설정에 지정합니다.

터미널 실행을 위해 각자의 PATH에도 SDK의 `bin` 폴더를 추가합니다. SDK가 PATH에서 정상 검색되면 사용자 설정의 `dart.flutterSdkPath`는 생략할 수 있습니다. PATH를 변경한 후 편집기를 완전히 종료하고 다시 실행합니다. 기존 프로세스에 변경이 반영되지 않으면 로그아웃하거나 PC를 재시작합니다.

설치 경로는 달라도 팀의 Flutter 버전은 동일하게 맞추는 것을 권장합니다. 현재 프로젝트 검증 버전은 Flutter 3.44.4 / Dart 3.12.2이고 `frontend/pubspec.yaml`의 Dart 요구사항은 3.12.2 이상, 4.0 미만입니다. `flutter --version`으로 확인하고 `pubspec.lock`을 공유해 의존성 버전을 맞춥니다. `.env`는 앱 설정용이며 Flutter SDK 탐색 경로를 지정하는 파일이 아닙니다.

## Cursor / VS Code에서 Flutter 실행

1. `PLM` 폴더를 편집기에서 엽니다. Dart와 Flutter 확장이 설치되어 있고 이 작업 영역에서 활성화되어 있는지 확인합니다.
2. 위의 개인 사용자 설정 또는 PATH로 본인의 Flutter SDK 경로를 지정합니다.
3. `Ctrl+Shift+P` → `Developer: Reload Window`를 실행하고 `frontend/lib/main.dart`를 다시 엽니다.
4. `main()` 위에 표시되는 `Run | Debug`로 실행하거나, `Ctrl+Shift+D`에서 `PLM: Chrome`을 선택하고 `F5`를 누릅니다.
5. 기기를 바꾸려면 `Ctrl+Shift+P` → `Flutter: Select Device` 또는 하단 상태 표시줄의 기기 이름을 누릅니다. 이 선택을 사용하려면 실행 항목을 `PLM: 선택한 기기`로 설정합니다. `PLM: Chrome`은 항상 Chrome으로 실행합니다.

실행 버튼은 `main()` 위에, 기기 선택은 보통 편집기 하단 상태 표시줄에 나타납니다. 상태 표시줄이 숨겨져 있으면 `View → Appearance → Status Bar`를 켭니다.

## 실행 전 준비

SDK의 `bin` 폴더를 PATH에 추가한 후 PowerShell에서 다음 명령을 실행합니다.

```powershell
cd frontend
flutter pub get
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
flutter run -d chrome
```

실제 연동에는 `frontend/.env`의 Backend·Supabase 공개 설정과 `backend/.env`의 Supabase 서버 설정이 필요합니다. 백엔드에 등록된 계정으로 로컬 또는 `FRONTEND_ORIGIN`과 일치하는 운영 Web 앱에서 시작하면 아내 계정 세션을 발급하고, 메뉴의 계정 전환으로 남편 세션을 선택할 수 있습니다. 현재 앱의 진입 경로와 화면 연결 상태는 [Frontend README](frontend/README.md)를 참고하세요.

실제 대화에는 백엔드 `LLM_API_KEY`가 필요합니다. 루틴 생성에는 오늘 컨디션·할 일 저장과 AI 설정이 필요하며, AI 생성 실패 시 백엔드 폴백 루틴이 저장될 수 있습니다. 연결 실패 시 실제 앱은 로컬 예시로 자동 대체하지 않습니다. `PLM_PREVIEW=true`로 명시적으로 실행한 미리보기에서만 로컬 예시를 사용합니다.

일반 앱의 `/wife/live`와 `/husband/live`는 오늘 감지 기록과 집계를 API로 조회하며 카메라를 열지 않습니다. 카메라 분석 기술 데모는 `frontend` 폴더에서 `flutter run -d chrome -t lib/main_movement_debug.dart`로 별도 실행합니다.

편집기의 SDK 경로 설정은 Windows PATH 자체를 변경하지 않습니다. PATH 설정 전에는 `& '본인의 SDK 경로/bin/flutter.bat' pub get`처럼 전체 경로로 실행할 수 있습니다.

SDK가 저장소 밖에 있고 제한된 실행 환경에서 `bin/cache/lockfile` 접근 오류가 발생하면, SDK 폴더에 현재 사용자의 쓰기 권한이 있는 일반 터미널에서 Flutter 명령을 실행합니다. 프로젝트 파일 권한 문제가 아니라 Flutter 도구가 SDK cache를 갱신하는 과정에서 발생할 수 있습니다.

## 버튼이나 기기가 보이지 않을 때

- `Flutter: Select Device` 명령 자체가 없다면 확장의 활성화 여부, 작업 영역 신뢰 여부, SDK 경로를 확인한 뒤 창을 다시 로드합니다. 필요하면 `frontend` 폴더를 직접 열어 Flutter 프로젝트 인식을 확인합니다. 이때 루트 `.vscode` 설정이 적용되지 않으므로 사용자 설정에서 SDK 경로를 지정합니다.
- 파일 오른쪽 아래 언어 모드가 `Dart`인지 확인합니다. `editor.codeLens`와 `dart.showMainCodeLens`가 켜져 있어야 `main()` 위 실행 링크가 표시됩니다.
- `flutter doctor -v`와 `flutter devices`로 SDK 상태와 실행 가능한 기기를 확인합니다. PATH가 없다면 본인의 `flutter.bat` 전체 경로를 사용합니다.
- Chrome 실행에는 Chrome 설치가 필요합니다. Android 기기는 Android SDK 설정과 실행 중인 에뮬레이터 또는 USB 디버깅을 허용한 실제 기기가 필요합니다.
- 현재 프로젝트에는 `web` 플랫폼만 준비되어 있고 `android` / `ios` 폴더가 없습니다. 모바일 앱 실행은 해당 플랫폼 프로젝트와 개발 환경을 추가한 후 가능합니다. Windows에서는 iOS 앱을 빌드하거나 iOS 시뮬레이터를 실행할 수 없습니다.
- `.env` asset 오류가 나면 `frontend/.env.example`을 `frontend/.env`로 복사합니다. 기존 `.env`는 덮어쓰지 않습니다.

백엔드 설치와 환경변수 목록은 [README](README.md)를 참고하세요.

### 오늘 기록 초기화 API 준비

아내 메뉴의 `초기화` 버튼을 사용하기 전에 `supabase/migrations/20260922000000_reset_daily_experience.sql`, `20260922010000_reset_today_posture_events.sql`, `20260923000000_reset_today_family_requests.sql`을 연결된 Supabase 프로젝트에 순서대로 적용해야 합니다. 앞선 마이그레이션이 이미 적용됐다면 새 파일만 적용합니다. 마이그레이션 없이 버튼을 누르면 API가 503을 반환하거나 기존 함수가 오늘 가사 요청 항목·남편 알림·모션 기록을 남길 수 있습니다. 초기화는 서버가 계산한 KST 오늘 날짜에만 적용되며, 삭제 후 되돌리려면 백업이 필요합니다. `POST /api/v1/care/today/reset`은 아내 로그인 세션으로만 호출할 수 있습니다. DB에서 `daily_conditions`만 직접 삭제하면 루틴·리포트·가사 요청·남편 알림·오늘 모션 감지 기록은 초기화되지 않으므로 이 API를 사용합니다. 모션 감지 기록은 `posture_events.started_at`의 KST 오늘 범위로 삭제하고, 캘리브레이션 기준선(`posture_calibration_profiles`)과 모션 동의 설정(`motion_consents`)은 유지합니다. 카메라 스트리밍 중에는 새 감지 기록이 다시 저장될 수 있으므로 스트리밍을 종료한 뒤 초기화합니다.

건강 가이드 영상을 사용하려면 `supabase/migrations/20260923120000_health_exercise_videos.sql`을 연결된 프로젝트에 적용합니다. 이 마이그레이션은 부위별 YouTube 영상 카탈로그를 만들고 허리·손목·골반·다리 영상 4건을 등록합니다. 로컬에서 적용할 때는 Backend 전용 `backend/.env`의 `SUPABASE_DB_URL`에 Supabase Pooler PostgreSQL 연결 문자열을 설정한 뒤 해당 SQL을 실행합니다. DB 연결 문자열은 Frontend 환경이나 빌드 산출물에 포함하지 않습니다. 백엔드의 건강 가이드 조회는 이 테이블을 읽으므로 마이그레이션을 적용하지 않은 서버에서는 `/api/v1/health/today`가 저장소 오류를 반환할 수 있습니다.

전신 운동 영상은 기본 영상 카탈로그 적용 후 `supabase/migrations/20260923130000_health_full_body_video.sql`을 적용합니다. 이 마이그레이션은 허용 부위에 `whole`을 추가하고 전신 영상의 재생 시간과 대상 임신 분기를 저장합니다.

## Backend 로컬 실행

현재 계정·일일 기록·가족 공유 API는 Supabase 저장소에 연결됩니다. Bearer 토큰 검증과 데이터 접근에 백엔드 Supabase 설정이 필요합니다.

```powershell
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

OpenAPI 문서는 `http://localhost:8000/docs`에서 확인합니다. 엔드포인트 목록은 [API 문서](docs/api.md)를 참고하세요.

참고: [Flutter 편집기 실행 안내](https://docs.flutter.dev/tools/vs-code), [Dart 확장 설정](https://dartcode.org/docs/settings/).

## 프론트엔드 API 연결 설정

### 연동 정보 없는 화면 미리보기

`frontend/`에서 다음과 같이 실행하면 계정·프로필·배우자 연결이 없어도 구현된 아내·남편 화면 URL을 직접 열 수 있습니다. 이 모드는 기존 Mock 데이터를 사용하며 실제 API, Supabase, OpenAI를 호출하지 않습니다. 화면의 데이터와 채팅 답변은 시연용 예시입니다.

```powershell
flutter run -d chrome --dart-define=PLM_PREVIEW=true
```

예: `/wife/home`, `/wife/meal`, `/wife/house`, `/wife/health`, `/wife/sleep`, `/wife/calendar`, `/wife/report/2026-09-13`, `/wife/chat`, `/husband/calendar`, `/husband/notifications`, `/husband/report/morning/2026-09-13`, `/husband/requests/demo-request`. 프로필 설정과 초대 경로도 직접 열 수 있습니다. 미리보기 플래그 없이 실행하면 기존 인증·연동 경로와 API 오류 상태를 유지합니다.

1. `frontend/.env.example`을 `frontend/.env`로 복사하고 `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BACKEND_URL`을 입력합니다. `SUPABASE_ANON_KEY`에는 Supabase 공개 키만 사용합니다. service role 키나 서버 비밀 값은 프론트엔드에 넣지 않습니다.
2. 백엔드가 같은 Supabase 프로젝트를 사용하도록 백엔드 실행 환경을 설정하고, `BACKEND_URL`의 주소에서 FastAPI를 실행합니다. 브라우저에서 실행하는 경우 백엔드 CORS에 허용된 로컬 출처를 사용합니다.
3. Backend의 비공개 `backend/.env`에 `PLM_WIFE_EMAIL`, `PLM_WIFE_PASSWORD`, `PLM_HUSBAND_EMAIL`, `PLM_HUSBAND_PASSWORD`를 설정하고 Backend를 재시작합니다. 두 계정은 Supabase Auth에 등록되어 있어야 합니다. 계정 비밀번호를 `frontend/.env`에 넣지 않습니다.
4. 앱을 열면 아내 계정으로 자동 로그인합니다. 아내·남편 메뉴의 `계정 전환` 버튼은 실제 Supabase 세션을 교체합니다. 새로고침하면 다시 아내 계정으로 시작합니다. 계정 상태 조회 API가 역할과 프로필 완료 여부를 결정합니다.

홈의 주차별 안내는 `GET /api/v1/routine/home`에서 조회합니다. 오늘 컨디션이나 루틴이 아직 없어도 프로필의 출산예정일이 저장되어 있으면 주차와 안내 문구를 반환합니다. 이 API가 503이면 Supabase의 `pregnancy_profiles` 연결을 확인합니다.

챗봇의 `GET /api/v1/chat/messages`는 날짜를 생략하면 최근 대화 200건을 날짜 경계 없이 반환합니다. 특정 날짜만 점검할 때는 `?date=YYYY-MM-DD`를 사용합니다.

`SUPABASE_URL`과 `SUPABASE_ANON_KEY`가 모두 비어 있으면 기존 로컬 화면 흐름을 사용합니다. 한쪽만 입력한 상태는 연결 설정이 완료된 것으로 취급하지 않습니다. API 요청에서 401이 나오면 Supabase 로그인 세션을, 403이 나오면 요청 Origin과 Backend의 `FRONTEND_ORIGIN`을, 503이 나오면 백엔드와 Supabase 연결을 확인합니다. 자동 계정 진입 API는 localhost 또는 `FRONTEND_ORIGIN`과 정확히 일치하는 Web 앱에서 사용할 수 있습니다. Flutter Web의 `.env`는 빌드에 포함되므로 계정 비밀번호를 넣지 마세요.

백엔드 프로필 API는 생년월일을 저장하고 반환합니다. Frontend는 마지막 생리 시작일만 선택한 경우 계산값을 화면에 표시하되, 저장 요청에는 마지막 생리 시작일만 보내 Backend가 출산예정일을 계산하도록 합니다. 가이드 응답의 `item_id`로 건강 활동 완료와 수면 환경 변경을 저장합니다. 루틴 생성 시 컨디션 저장 → 예정 활동 저장 → 루틴 생성 순서를 유지합니다. 401은 로그인 세션, 404는 오늘 루틴 또는 기록의 존재 여부, 409는 선행 입력, 422는 입력값, 503은 서버 연결 상태를 확인하세요.

루틴 생성에는 약 10~15초가 걸릴 수 있습니다. `AI 루틴 생성중...` 창은 요청이 끝날 때 자동으로 닫힙니다. 실패 안내가 표시되면 예정 활동 선택값을 유지한 상태에서 다시 제출할 수 있습니다.

# 일일 흐름의 가족 초대 화면

컨디션을 새로 저장하고 예정 활동에서 `다음`을 누르면 활동만 저장되고 가족 초대 화면으로 이동합니다. 이 화면에서 `초대하기` 또는 `나중에`를 선택한 뒤 루틴 생성 요청이 시작됩니다. 이미 연결된 계정은 초대 링크를 다시 만들지 않으며, `초대하기`를 누르면 백엔드의 배우자 이름으로 연결 결과를 진행 창에 표시하고 별도의 루틴 생성 버튼 없이 바로 생성합니다. `나중에`를 누르면 연결 확인 표시를 저장하지 않아 메뉴의 `가족 초대하기`를 계속 사용할 수 있습니다.

연결 결과를 확인했는지는 계정별 브라우저 localStorage에 저장하는 화면 표시 상태입니다. 실제 연결 권한은 백엔드의 배우자 연결 API 응답을 기준으로 합니다. 브라우저 저장소를 지우면 연결된 계정도 메뉴에서 가족 초대 화면에 다시 들어갈 수 있습니다. 루틴 생성이 실패하면 초대 화면에 머물러 다시 시도할 수 있습니다.

아내 메뉴의 `초기화` API가 성공하면 해당 계정의 프로필 재입력 필요 상태와 가족 초대 결과 확인 표시를 저장하고, 빈 프로필 1단계로 이동합니다. 이후 프로필 설정 → 가족 초대 → 홈 → 컨디션 입력 → 할 일 입력 → AI 루틴 생성 → 홈 순서로 다시 진행합니다. 할 일 화면에서 루틴 생성에 실패하면 같은 화면에서 다시 시도할 수 있습니다. 프로필 저장 전 새로고침하거나 계정을 전환했다 돌아와도 프로필 단계가 유지됩니다. 기존 DB 프로필과 배우자 계정 연결은 삭제하지 않으며, 새 프로필을 완료하면 기존 프로필 값을 갱신합니다. API가 실패하면 프로필과 초대 표시 상태는 유지됩니다.

## 개발 도구 실행

PC 웹캠 분석 도구는 저장소 루트에서 실행합니다. `--check`는 카메라를 열지 않고 모델과 의존성을 확인합니다.

```powershell
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo --check
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo
```

생활루틴 지식 적재 도구는 `tools/rag_ingest`에서 별도 의존성을 설치하고 `.env.example`을 복사해 로컬 설정을 채웁니다. SQL을 연결된 Supabase에 적용한 뒤 필요한 단계만 실행합니다. 서버 비밀 키는 Flutter 환경에 넣지 않습니다.

```powershell
cd tools/rag_ingest
python -m pip install -r requirements.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
python 02_translate_chunk_embed_upload.py --step all
```

## Railway와 GitHub Pages 배포

현재 운영 주소는 다음과 같습니다.

```text
Web App: https://lgdxdoraemi.github.io/PLM/
Backend API: https://plm-backend-production-cc76.up.railway.app
Swagger UI: https://plm-backend-production-cc76.up.railway.app/docs
Healthcheck: https://plm-backend-production-cc76.up.railway.app/health
```

전체 배포 개요와 빠른 확인 절차는 [루트 README](README.md#배포-구조), 서비스별 상세 설정은 [Frontend README](frontend/README.md#github-pages-배포)와 [Backend README](backend/README.md#railway-배포)를 함께 참고합니다.

### 1. Railway Backend 생성

Railway에서 GitHub 저장소를 연결하고 Backend 서비스를 생성한 뒤 아래 값을 사용합니다.

```text
Root Directory: backend
Dockerfile Path: /backend/Dockerfile
Start Command: python -m app.server
Healthcheck Path: /health
Watch Path: /backend/**
```

Backend는 `backend/Dockerfile`로 빌드합니다. Dockerfile에는 MediaPipe/OpenCV가 Railway의 headless Linux 환경에서 요구하는 `libxcb`, OpenGL 및 GLib 런타임 패키지가 포함되어 있습니다. `ImportError: libxcb.so.1`이 발생하면 Railpack 빌드가 아니라 저장소 루트 기준 `/backend/Dockerfile`을 사용하는지 먼저 확인합니다.

`app.server`는 Railway가 주입한 `PORT`를 Python에서 직접 읽고 검증한 뒤 Uvicorn을 시작합니다. Start Command에서 `$PORT`를 직접 사용하면 Railway 실행 방식에 따라 문자열로 전달될 수 있으므로 `python -m app.server`를 유지합니다.

Root Directory로 `backend/`만 배포 범위에 포함하고, Watch Path로 Backend 변경이 있을 때만 새 배포를 생성합니다. `tests/`와 문서는 실행 시 import되지 않으며 크기가 작으므로, GitHub 연동 배포에서 보장되지 않는 별도 ignore 설정은 추가하지 않습니다. `models/pose_landmarker_full.task`는 모션 API가 런타임에 직접 사용하므로 제외하지 않습니다.

Railway Backend 서비스의 Variables에는 `backend/.env.example`을 기준으로 실제 사용하는 서버 설정을 입력합니다.

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
PLM_WIFE_EMAIL
PLM_WIFE_PASSWORD
PLM_HUSBAND_EMAIL
PLM_HUSBAND_PASSWORD
LLM_API_KEY
LLM_API_BASE_URL
THINQ_PAT
THINQ_COUNTRY_CODE
THINQ_CLIENT_ID
FRONTEND_ORIGIN=https://lgdxdoraemi.github.io
```

`SUPABASE_DB_URL`은 마이그레이션을 Railway에서 직접 실행할 때만 추가합니다. `SUPABASE_SERVICE_ROLE_KEY`, 계정 비밀번호, `LLM_API_KEY`, `THINQ_PAT`은 Railway Backend 서비스에만 저장합니다. Flutter 빌드 인자나 GitHub Repository Variable에 넣지 않습니다. 배포 후 Railway의 Public Networking에서 도메인을 생성하고 `https://<railway-domain>` 주소의 `/health`와 `/docs`를 확인합니다.

### 2. GitHub Repository Variables 설정

GitHub 저장소의 `Settings > Secrets and variables > Actions > Variables`에 다음 값을 추가합니다.

```text
API_BASE_URL=https://<railway-domain>
SUPABASE_URL=<Supabase Project URL>
SUPABASE_ANON_KEY=<Supabase public anon key>
```

`SUPABASE_ANON_KEY`는 브라우저 앱에 포함되는 공개 클라이언트 키입니다. Service Role Key는 입력하지 않습니다. 운영 Backend 주소가 확정되기 전에는 `API_BASE_URL`을 placeholder로 두고 배포하지 않습니다.

### 3. GitHub Pages 활성화 및 배포

GitHub 저장소의 `Settings > Pages > Build and deployment > Source`를 `GitHub Actions`로 선택합니다. `main`에 Frontend 또는 배포 Workflow 변경이 push되면 `.github/workflows/deploy-pages.yml`이 `frontend/`만 체크아웃하고 다음 빌드를 실행합니다.

```bash
flutter build web --release \
  --base-href "/PLM/" \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

첫 설정 뒤에는 Actions의 `Flutter Web GitHub Pages 배포`에서 `Run workflow`를 한 번 실행할 수 있습니다. 배포 주소는 `https://lgdxdoraemi.github.io/PLM/`입니다. Flutter Web은 기본 hash routing을 사용하므로 앱 내부 경로는 `/#/wife/home` 형태이며 Pages의 직접 경로 404를 피합니다.

배포 Artifact는 `frontend/build/web`만 업로드합니다. `frontend/test`, 로컬 IDE 설정, Android/iOS 파일, Backend와 프로젝트 문서는 Web 배포 결과에 포함되지 않습니다. Flutter가 생성하는 CanvasKit/Wasm 파일은 브라우저별 렌더러 호환에 필요하므로 임의로 제거하지 않습니다.

### 4. 배포 확인

1. `https://<railway-domain>/health`가 `{"status":"ok"}`를 반환하는지 확인합니다.
2. `https://<railway-domain>/docs`에서 OpenAPI 문서가 열리는지 확인합니다.
3. `https://lgdxdoraemi.github.io/PLM/`에서 앱을 열고 브라우저 개발자 도구의 API 요청 대상이 Railway URL인지 확인합니다.
4. Railway 배포 로그에 Pages Origin의 요청이 남고 CORS 오류가 없는지 확인합니다.

개별 단계는 `--step translate`, `--step embed`, `--step upload`로 실행할 수 있습니다.
