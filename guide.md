# 개발 환경 및 실행 안내

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

실행하면 `/`이 canonical `/entry`로 정규화되고 Mock Bootstrap이 사용자 상태를 확인합니다. 새 사용자는 실제 Entry 화면에서 `시작하기`를 눌러 Profile Setup으로 이동하고, Profile을 완료한 재방문 사용자는 `/wife/home`으로 바로 이동합니다. 알 수 없는 경로도 안전하게 `/entry`로 복구됩니다. ThinQ Host/실제 Session Adapter는 아직 없으므로 역할별 직접 URL 접근 차단은 보장하지 않습니다. Browser 주소의 `/wife/home`, `/wife/menu`, `/wife/report/2026-09-13`, `/partner/calendar`, `/partner/requests/demo-request`를 직접 열어 Mock UI를 확인할 수 있습니다.

온보딩에서 출산예정일 또는 마지막 생리 시작일을 입력할 수 있습니다. 마지막 생리 시작일을 선택하면 출산예정일 입력칸에 280일 뒤 계산값이 바로 표시됩니다. 출산예정일을 직접 선택하면 마지막 생리 시작일을 지우고 선택한 값을 사용합니다. 예정일, 생년월일, 100~220cm 신장, 30~250kg 임신 전 체중, 초산/경산, 단태/다태가 모두 유효해야 완료 사용자로 판정합니다. Supabase 로그인 환경에서는 단계별 프로필 API가 생년월일을 포함한 값을 서버에 저장합니다. 설정 없는 Mock 실행에서는 완료 Profile을 브라우저 localStorage의 `plm.demo.profile.v1` 키에 저장해 새로고침 후에도 Home/Menu의 임신 주수와 재방문 분기를 유지합니다.

새 사용자 상태를 다시 시연하려면 Chrome 개발자 도구의 `Application` → `Local Storage`에서 현재 origin의 `plm.demo.profile.v1` 항목을 삭제하고 `/entry`를 새로고침합니다. Profile Setup을 끝내면 같은 코드에서 완료 사용자 상태로 전환되며, 이후 `/entry` 재진입 시 Home으로 이동합니다. 브라우저 저장소 접근이 차단된 환경에서는 현재 실행 중인 메모리 상태만 유지되고 새로고침 후 Entry로 돌아올 수 있습니다.

`/wife/chat`을 직접 열거나 하단 챗봇 탭으로 이동하면 뒤로가기 버튼이 없습니다. 식사 가이드에서는 `/wife/chat?source=meal&period={mealPeriod}`로 이동하며 이 경우에만 뒤로가기가 활성화됩니다. `household`, `health`, `sleep` source도 동일한 복귀 규칙을 지원하므로 해당 가이드에서 챗봇 진입 UI가 추가될 때 같은 Route helper를 사용합니다.

`/wife/home`의 AI Routine은 실제 AI API가 없어도 실행됩니다. 당일 컨디션 미입력 시 컨디션 CTA가 표시되고, 입력과 예정 활동 선택을 마치면 `MockRoutineService`가 식사·가사·건강·수면 가이드를 제공합니다. Service 오류 시 화면을 비우지 않고 기본 Routine과 재시도 버튼을 표시합니다.

가이드 상세 화면은 `/wife/meal`, `/wife/household`, `/wife/health`, `/wife/sleep`에서 확인할 수 있습니다. Meal·Health·Sleep 데이터와 Household 공유는 local Mock 상태를 사용합니다. Household에서 공유하면 `PartnerRequestStore`에 실제 request ID가 생성되고 `/partner/requests/{requestId}` 계약으로 조회할 수 있습니다. Household의 가전 항목 `실행`과 Sleep의 수면 환경 전체 실행은 현재 실제 기기에 명령을 보내지 않고 로컬 실행 기록을 남깁니다. 각 요청은 오늘 날짜의 메모리 이력에 1회 기록되며, 새로고침하면 이 이력은 초기화됩니다. 사용자 화면의 팝업에는 기기 연동 상태나 개발 단계 안내를 표시하지 않습니다.

Calendar는 `/wife/calendar`과 `/partner/calendar`에서 날짜를 화면 선택 상태로 관리합니다. 선택한 기록의 상세 버튼은 같은 날짜를 `YYYY-MM-DD` 형식으로 `/wife/report/{date}` 또는 `/partner/report/{date}`에 전달합니다. 존재하지 않거나 `2026-02-31`처럼 유효하지 않은 날짜는 오늘 기록으로 대체하지 않고 빈 상태를 표시합니다. Desktop에서는 Calendar와 상세가 나란히 보이고 Mobile에서는 상세가 달력 아래에 이어집니다.

Wife Report에서 `저장하고 마치기`를 누르면 Calendar로 이동하며 같은 날짜가 선택됩니다. 오늘 날짜의 Mock 리포트라면 Home의 컨디션 입력 상태도 초기화됩니다. 리포트 내용은 아직 당일 입력/완료 내역으로 생성되지 않는 샘플 기록이고 영구 저장되지 않습니다. 가전 자동 실행 수치는 가사·수면 가이드의 시연 요청 합계이며, 실제 기기 실행 횟수가 아닙니다. 모션 감지 횟수는 연동 전이므로 0으로 표시합니다.

Partner는 `/partner/calendar`를 시작 화면으로 사용하며 Header의 알림 버튼만 `/partner/notifications`로 연결됩니다. 알림 항목은 `/partner/report/{date}` 또는 `/partner/requests/{requestId}`로 이동합니다. Request 완료 결과의 `캘린더로 돌아가기`를 누르면 `/partner/calendar`에서 요청·확인·완료 집계가 갱신됩니다. Partner 화면에는 Bottom Navigation이나 Profile 버튼이 없으며, Phase 2 실시간 화면은 Calendar의 명시적 CTA로만 진입합니다.

`/wife/movement`와 `/partner/movement`는 Phase 2 화면 구성 확인용 Local Mock입니다. 일반 `flutter run`에서는 카메라 권한 요청, MediaPipe 분석, WebSocket 또는 실시간 센서 연결이 발생하지 않습니다. 별도 기술 데모가 필요한 경우에만 `flutter run -d chrome -t lib/main_movement_debug.dart`를 사용하며, 이 진입점은 제품 Router와 연결되지 않습니다.

남편 초대 화면은 연결 설정 여부와 관계없이 초대 카드와 `초대장 보내기`·`나중에` 버튼을 표시합니다. `초대장 보내기`를 누르면 ThinQ 전달 연동이 필요하다는 안내가 나타나며, 전송 성공으로 처리하거나 링크를 생성하지 않습니다. `나중에`는 기존 화면 이동을 유지합니다. 개발용 로그나 화면 문구에 실제 Token을 출력하지 않습니다.

연동 환경 값이 없는 화면 미리보기에서는 각 기능의 기본 레이아웃과 로컬 예시 콘텐츠를 볼 수 있습니다. 화면 상단의 `연동이 필요합니다` 안내로 예시 상태를 구분합니다. 로그인과 Backend 연결이 설정된 실행에서는 API 오류 시 로컬 예시로 대체하지 않고 해당 화면의 오류 또는 빈 상태를 표시합니다.

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

## Backend Skeleton 로컬 확인

`account`, `care`, `family` API는 실제 Supabase adapter가 연결되기 전까지 프로세스 메모리 Stub을 사용합니다. 서버 재시작 시 Stub 데이터는 초기화됩니다. Bearer token 검증은 기존 Supabase Auth 경계를 그대로 사용하므로 `.env`에 Backend용 Supabase 설정이 필요합니다.

```powershell
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

OpenAPI 문서는 `http://localhost:8000/docs`에서 확인합니다. 도메인 소유권과 Stub 교체 순서는 [Backend Domain Ownership](backend/DOMAIN_OWNERSHIP.md)을 따릅니다. Routine·Movement 보호 영역과 기존 migration은 이번 Skeleton에서 변경하지 않습니다.

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
3. Supabase Auth에 등록된 계정으로 앱의 로그인 화면에서 로그인합니다. 현재 앱에는 계정 생성 화면이 없으므로 계정을 먼저 준비해야 합니다.
4. 로그인 뒤 계정 상태 조회 API가 역할과 프로필 완료 여부를 결정합니다. 컨디션을 입력한 뒤 화면을 새로고침하면 오늘 기록을 서버에서 다시 읽습니다.

`SUPABASE_URL`과 `SUPABASE_ANON_KEY`가 모두 비어 있으면 기존 로컬 화면 흐름을 사용합니다. 한쪽만 입력한 상태는 연결 설정이 완료된 것으로 취급하지 않습니다. API 요청에서 401이 나오면 Supabase 로그인 세션을, 503이 나오면 백엔드와 Supabase 연결을 확인합니다. 현재 워크스페이스에는 실제 Supabase 연결 값과 백엔드 실행용 `.env`가 없어 이 환경에서 실DB 왕복은 검증할 수 없습니다.

백엔드 프로필 API는 생년월일을 저장하고 반환합니다. Frontend는 마지막 생리 시작일만 선택한 경우 계산값을 화면에 표시하되, 저장 요청에는 마지막 생리 시작일만 보내 Backend가 출산예정일을 계산하도록 합니다. 가이드 응답의 `item_id`로 건강 활동 완료와 수면 환경 변경을 저장합니다. 루틴 생성 시 컨디션 저장 → 예정 활동 저장 → 루틴 생성 순서를 유지합니다. 401은 로그인 세션, 404는 오늘 루틴 또는 기록의 존재 여부, 409는 선행 입력, 422는 입력값, 503은 서버 연결 상태를 확인하세요.

루틴 생성에는 약 10~15초가 걸릴 수 있습니다. `AI 루틴 생성중...` 창은 요청이 끝날 때 자동으로 닫힙니다. 실패 안내가 표시되면 예정 활동 선택값을 유지한 상태에서 다시 제출할 수 있습니다.
