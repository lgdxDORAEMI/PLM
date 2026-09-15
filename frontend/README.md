# PLM Frontend

PLM Frontend는 임산부와 배우자의 생활관리 경험을 제공하기 위한 Flutter Web 앱입니다. 현재 제품 화면은 구현 전이며, 초기 실행 화면과 Web 전용 모션 인식 데모가 동작합니다. 요구사항 분석, Architecture, Design System, Component System과 화면 구현 계획은 STEP 1~5까지 완료되었습니다.

## 지원 플랫폼

| 플랫폼 | 상태 |
| --- | --- |
| Web / Chrome | 현재 지원 |
| Android | 미지원 — 플랫폼 프로젝트와 Web 전용 구현 분리가 필요 |
| iOS | 미지원 — 플랫폼 프로젝트와 macOS/Xcode 환경 구성이 필요 |

`lib/app.dart`가 `dart:html` 기반 모션 카메라 구현을 직접 연결하고 있으므로 현재 코드는 Web 전용입니다. 로컬에 생성 산출물 형태의 `android/` 또는 `ios/` 폴더가 보이더라도 저장소에 포함된 정식 플랫폼 프로젝트로 간주하지 않습니다.

## 현재 구현 상태

### 구현됨

- `.env` 로딩과 `BACKEND_URL` 설정
- Supabase URL과 anon key가 모두 존재할 때만 Flutter client 초기화
- Material 3 기반 초기 실행 확인 화면
- 임시 버튼을 통한 모션 인식 데모 진입
- 브라우저 카메라 프레임 캡처 및 WebSocket 전송
- 캘리브레이션 진행률, 실시간 자세·부담 상태와 landmark 오버레이 표시
- 카메라와 WebSocket을 추상화한 Controller 단위 테스트

### 설계 완료, 구현 전

- 임산부 프로필과 배우자 초대
- 오늘의 컨디션 및 예정 활동 입력
- 통합 Home과 식사·가사·건강·수면 가이드
- 식사 재조정 채팅
- 루틴 완료 기록, Daily 리포트와 캘린더
- 배우자용 리포트, 요청, 알림, 프로필 화면
- Design Token과 공통/Feature Component
- Routing, 전역 상태와 Mock Service 구조

화면 구현은 [화면 구현 계획](../docs/development/05_ui_implementation_plan.md)의 `UI-001`부터 한 화면씩 진행합니다. 실제 API가 없는 기능은 다음 의존 방향을 유지합니다.

```text
Page
→ Feature Widget
→ State / Controller
→ Frontend Service
→ Mock Service
```

## 구조

```text
lib/
├── core/config/app_config.dart
├── features/movement/
│   ├── models/
│   ├── browser_camera_frame_source.dart
│   ├── browser_live_transport.dart
│   ├── movement_controller.dart
│   ├── movement_overlay_painter.dart
│   └── movement_screen.dart
├── app.dart
└── main.dart

test/features/movement/
├── models/live_message_test.dart
├── movement_controller_test.dart
└── fakes.dart
```

향후 Feature 구조는 기존 폴더를 유지하면서 필요한 영역만 추가합니다. 확정된 제안은 [Frontend Architecture](../docs/development/02_frontend_architecture.md)를 참고하세요.

## 실행

요구사항:

- Flutter stable
- Dart 3.12.2 이상, 4.0 미만
- Chrome
- 실행 중인 Backend — 초기 화면에는 선택 사항, 모션 데모에는 필수

```powershell
flutter pub get
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
flutter run -d chrome
```

`.env` 예시:

```dotenv
SUPABASE_URL=
SUPABASE_ANON_KEY=
BACKEND_URL=http://localhost:8000
```

`.env`는 `pubspec.yaml`에 asset으로 등록되어 있으므로 파일이 없으면 실행 또는 빌드가 실패합니다. Supabase 값은 둘 다 비워둘 수 있지만 하나만 입력하지 마세요.

SDK 탐색이나 VS Code 실행 문제가 있으면 [개발 환경 및 실행 안내](../guide.md)를 확인하세요.

## 모션 인식 데모

1. Backend를 `localhost:8000`에서 실행합니다.
2. Frontend를 Chrome에서 실행합니다.
3. 초기 화면의 **모션 인식 데모 보기**를 선택합니다.
4. 브라우저 카메라 권한을 허용하고 캘리브레이션과 실시간 상태를 확인합니다.

현재 데모는 Backend의 `WS /api/v1/movement/live/stream`에 JPEG 프레임을 약 5fps로 전송합니다. WebSocket은 로컬 `localhost` 또는 `127.0.0.1` origin만 허용합니다.

이 기능은 Phase 2 검증용 데모입니다. MVP 제품 UI의 건강·수면 가이드는 모션 데이터가 아니라 Mock Data와 컨디션 입력을 기준으로 구현할 예정입니다. 세부 제약과 수동 검증 항목은 [Movement README](lib/features/movement/README.md)를 참고하세요.

## 검증

```powershell
flutter analyze
flutter test
flutter build web
```

일반 테스트는 카메라와 WebSocket fake를 사용하므로 Dart VM에서 실행할 수 있습니다. 실제 `getUserMedia`, 브라우저 미리보기, 카메라 권한, Backend 연결 및 화면 이탈 시 리소스 정리는 `flutter run -d chrome`으로 수동 확인해야 합니다.

## 개발 기준

- 기능과 사용자 흐름은 `docs/requirements/**`, `docs/서비스흐름도/**`를 우선합니다.
- 화면 정보 구조는 `docs/screens/**`를 참고합니다.
- 색상, 타이포그래피, 간격과 Component 상태는 `DESIGN.md`를 최우선으로 적용합니다.
- Widget에 Mock JSON이나 대규모 상태 로직을 직접 넣지 않습니다.
- Backend endpoint를 임의로 만들거나 확정하지 않습니다.
- 상세 운영 규칙은 [Frontend 작업 운영 기준](../docs/development/frontend_workflow.md)을 따릅니다.

## 관련 문서

- [전체 프로젝트 README](../README.md)
- [Frontend 분석](../docs/development/01_frontend_analysis.md)
- [Frontend Architecture](../docs/development/02_frontend_architecture.md)
- [Design System](../docs/development/03_design_system.md)
- [Component System](../docs/development/04_component_system.md)
- [UI 구현 계획](../docs/development/05_ui_implementation_plan.md)
