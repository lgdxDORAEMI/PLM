# PLM Frontend

PLM Frontend는 임산부와 배우자의 생활관리 경험을 제공하기 위한 Flutter Web 앱입니다. 화면은 기존 공통 UI를 사용하고, 라우팅은 `docs/development/ROUTE_MAP_V2.md`의 아내·남편 경로를 따릅니다. 실제 데이터가 없는 화면은 연동 상태를 표시하며, 명시적 화면 미리보기 모드에서는 로컬 예시로 구현된 경로를 확인할 수 있습니다.

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
- DESIGN.md 기반 Theme와 공통 Design Token
- 밝은 neutral surface 기반의 공통 Shell과 선택 상태 중심의 Pregnancy accent
- Button, Input, Card, SelectionCard, TopAppBar, BottomNavigation
- 아내 `/wife/*`, 남편 `/husband/*`, 공통 `/entry`·`/invite/accept` 경로를 구분하는 중앙 Router
- ThinQ 인증 계정 상태와 `activeRole` 분리, 계정별 역할 복원 및 역할 경로 접근 제한
- 역할 전환 시 대상 역할 홈으로 이동하고 이전 navigation stack 제거
- 프로필·배우자 초대의 온보딩/수동 진입 Context 분리
- 역할별 Header, Wife Mobile 4개 Bottom Navigation·Desktop Navigation Rail, Partner Calendar 중심 Navigation
- Home·Meal·Health·Household·Sleep·Calendar·Report·Movement의 viewport별 composition
- `/`와 잘못된 경로를 인증·역할·프로필·연동 상태에 따라 안전한 시작 경로로 보내는 Route guard
- 최초 직접 접근에서 다른 역할 URL을 현재 역할 Home 주소로 교체하고, 끼니별 식사 상세 URL을 새로고침 후에도 복원
- 아내 프로필 미완료 시 첫 단계, 연결된 남편은 캘린더, 미연결 남편은 초대 필요 안내로 진입
- Web Demo Profile의 localStorage 복원
- Web에서 계정별 `activeRole` 복원. 실제 역할 접근권과 ThinQ 로그인은 향후 호스트 연동이 필요
- 아내 프로필 생년월일·DB 알레르기 항목, ThinQ 알림 초대, 챗봇 끼니 context 반영
- 실시간 화면을 오늘 로그 전용으로 정리하고 확인 상태·과거 로그·개발용 기기 상태 제거
- Daily 리포트·캘린더의 미확정 관절 수치를 홈캠 주의사항 문구로 교체
- 남편은 캘린더를 Home으로 사용하고 Bottom Navigation 없이 알림·리포트·요청·오늘 실시간으로 이동
- 남편 알림 3종과 요청 카드 전체 상태, 완료 결과 전체 화면 구현
- 아내 가사 가이드 재진입 시 Backend 요청 목록에서 남편의 항목별 확인·완료 상태 복원
- Home 루틴 카드와 진행률을 상세 가이드와 같은 날짜의 `routine_items` 실행 상태에서 조회하고, 상세 화면 복귀 시 갱신
- `PLM_PREVIEW=true` 실행 시 인증·프로필·배우자 연결 없이 아내·남편 화면 경로를 로컬 예시로 직접 확인
- ThinQ 초대 handoff 성공 시 남편 연결 상태와 `activeRole`을 갱신한 뒤 캘린더로 진입
- 브라우저 카메라 프레임 캡처 및 WebSocket 전송
- 캘리브레이션 진행률, 실시간 자세·부담 상태와 landmark 오버레이 표시
- 카메라와 WebSocket을 추상화한 Controller 단위 테스트

기능별 FE–BE 연결 상태와 남은 연동 경계는 [FE–BE 연결 기준 상태](../docs/FE_BE_CONNECTION_STATUS.md)를 참고하세요.

### Skeleton 완료, 상세 UI 구현 전

- 임산부 프로필과 배우자 초대
- 오늘의 컨디션 및 예정 활동 입력
- 통합 Home과 식사·가사·건강·수면 가이드
- 식사 가이드 및 재조정 채팅의 화면 구성과 상태 표시. 실제 채팅 API가 없는 화면은 연동 필요 상태를 표시
- 루틴 완료 기록, Daily 리포트와 캘린더
- 배우자용 초대 수락, 리포트, 알림, 가사 요청 확인·완료 화면
- 화면별 실제 콘텐츠·상태·접근성 세부 구현
- Feature Controller와 테스트용 Mock Service

화면 구현은 [화면 구현 계획](../docs/development/05_ui_implementation_plan.md)의 `UI-001`부터 Placeholder를 한 화면씩 교체합니다. 전체 현황과 공용 파일 경계는 [Frontend 진행 현황](../docs/FRONTEND_PROGRESS.md)을 확인합니다. Mock Service는 테스트와 명시적 화면 미리보기에서 사용합니다.

```text
Page
→ Feature Widget
→ State / Controller
→ Frontend Service
→ API Service 또는 테스트용 Mock Service
```

## 구조

```text
lib/
├── core/config/app_config.dart
├── design_system/            # token, theme, 공통 component
├── routing/                  # 중앙 route 이름과 생성기
├── shared/widgets/           # 공통 Skeleton layout
├── features/*/screens/       # 화면별 독립 Placeholder
├── features/movement/
│   ├── models/
│   ├── browser_camera_frame_source.dart
│   ├── browser_live_transport.dart
│   ├── movement_controller.dart
│   ├── movement_overlay_painter.dart
│   └── movement_screen.dart
├── app.dart                  # Theme과 Router 조립
└── main.dart

test/
├── features/movement/
└── routing/app_router_test.dart
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
3. 제품의 실시간 화면은 Backend 데이터가 있으면 오늘 감지 로그를 표시합니다. 데이터 연결이 없으면 연동 필요 상태를 표시합니다.
4. 브라우저 카메라 권한을 허용하고 캘리브레이션과 실시간 상태를 확인합니다.

현재 데모는 Backend의 `WS /api/v1/movement/live/stream`에 JPEG 프레임을 약 5fps로 전송합니다. WebSocket은 로컬 `localhost` 또는 `127.0.0.1` origin만 허용합니다.

이 기능은 Phase 2 검증용 데모입니다. 세부 제약과 수동 검증 항목은 [Movement README](lib/features/movement/README.md)를 참고하세요.

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
- [Frontend 진행 현황](../docs/FRONTEND_PROGRESS.md)
