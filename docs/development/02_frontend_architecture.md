# Current Architecture

## 구조 요약

현재 `frontend/lib`는 초기 프로젝트에서 준비한 Feature-first 골격과 모션 인식 데모 구현으로 구성되어 있다.

```text
frontend/lib/
├─ core/
│  ├─ config/
│  │  └─ app_config.dart
│  ├─ constants/                 # 비어 있음
│  ├─ network/                   # 비어 있음
│  └─ utils/                     # 비어 있음
├─ features/
│  ├─ condition/                 # 비어 있음
│  ├─ meal/                      # 비어 있음
│  ├─ movement/
│  │  ├─ models/
│  │  ├─ browser_camera_frame_source.dart
│  │  ├─ browser_live_transport.dart
│  │  ├─ camera_frame_source.dart
│  │  ├─ live_transport.dart
│  │  ├─ movement_controller.dart
│  │  ├─ movement_overlay_painter.dart
│  │  └─ movement_screen.dart
│  ├─ profile/                   # 비어 있음
│  ├─ routine/                   # 비어 있음
│  └─ sleep/                     # 비어 있음
├─ models/                       # 비어 있음
├─ services/                     # 비어 있음
├─ widgets/                      # 비어 있음
├─ app.dart
└─ main.dart
```

## 현재 실행 및 의존 흐름

```text
main.dart
  └─ AppConfig.initialize()
      ├─ flutter_dotenv
      └─ optional Supabase.initialize()
  └─ PLMApp
      └─ 임시 실행 확인 화면
          └─ MovementScreen
              └─ MovementController
                  ├─ CameraFrameSource → BrowserCameraFrameSource
                  └─ LiveTransport → BrowserLiveTransport
```

## 현재 구조의 장점

- `main.dart`가 초기화, `app.dart`가 앱 구성을 담당하는 기본 책임 분리가 있다.
- `core`와 `features`가 이미 분리되어 있어 기존 방향을 유지하며 확장할 수 있다.
- `movement`는 카메라와 전송 계층을 Interface로 분리하고 생성자 주입을 사용한다.
- `MovementController`는 구체적인 `dart:html` 구현을 Import하지 않아 Controller 단위 테스트가 가능하다.
- 기존 `ChangeNotifier` 기반 상태 흐름은 Flutter 기본 도구와 잘 맞고 작은 Feature에는 충분히 단순하다.
- `AppConfig`가 환경 설정을 한 곳에서 관리한다.

## 현재 구조의 한계

- `app.dart`가 Theme, 임시 Page, Navigation, 구체적인 Browser 구현 조립까지 함께 담당한다.
- 제품용 Routing, 역할별 App Shell, 온보딩 Guard가 없다.
- Design System, 공통 Layout, 공통 상태 UI가 없다.
- 상태 관리와 Service 주입에 대한 앱 전체 규칙이 없다.
- `profile`, `condition`, `routine`, `meal`, `sleep`은 폴더만 존재하고 Requirements 전체를 포괄하지 못한다.
- 최상위 `models`, `services`, `widgets`의 사용 기준이 없어 향후 공용 코드가 무분별하게 모일 수 있다.
- `AppConfig`가 앱 시작 시 Supabase를 직접 초기화한다. 현재 UI 작업에서 이 결합을 확장하면 Mock 전환과 테스트가 어려워질 수 있다.
- `movement`의 Browser 구현이 `dart:html`에 직접 의존하므로 해당 Import가 앱 조립부로 퍼지면 Mobile Target을 컴파일할 수 없다.
- 모션 데모는 실제 Backend URI와 현재 `app.dart`에 직접 연결되어 있지만 제품 요구사항에서는 Phase 2다.

## 현재 의존성

`pubspec.yaml`에는 `flutter`, `flutter_dotenv`, `http`, `supabase_flutter`만 있으며 별도 상태 관리나 선언형 Routing Package는 없다. 현재 단계에서는 Package를 추가하지 않는다.

# Proposed Architecture

## 설계 원칙

기존 Feature-first 구조를 유지하면서 다음의 얕은 구조를 점진적으로 적용한다.

```text
App composition
  ├─ Core infrastructure
  ├─ Design System
  ├─ Shared, domain-neutral UI
  └─ Feature
      ├─ Page / Widget
      ├─ State / Controller
      ├─ Model
      └─ Service contract + Mock implementation
```

별도 `usecase`, `entity`, `repository`, `datasource` 계층을 반복해서 만들지 않는다. Feature가 실제로 복잡해질 때만 내부 파일을 분리한다.

## 유지

- `main.dart`와 `app.dart`의 진입점
- `core/config/app_config.dart`와 `core/{constants,network,utils}` 골격
- `features` 중심의 기능 분리
- 최상위 `models`, `services`, `widgets` 디렉터리
- `movement`의 `CameraFrameSource`, `LiveTransport` Interface 및 생성자 주입 방식
- `MovementController`의 `ChangeNotifier` 기반 상태 관리와 기존 테스트 가능 구조
- 환경별 구현을 호출부에서 조립하는 원칙

## 개선

- `app.dart`는 `MaterialApp.router`, Theme, 전역 의존성 Scope를 조립하는 Composition Root 역할만 담당한다.
- 임시 시작 화면과 모션 데모 조립 코드는 제품 Routing과 분리한다.
- Feature 내부 파일은 필요에 따라 `pages`, `widgets`, `state`, `models`, `services`로 분류한다.
- Controller의 공개 변경 필드를 Immutable State 하나로 묶어 상태 전이를 명확히 한다.
- 비동기 처리의 Loading, Success, Empty, Error를 State에서 표현하고 Widget의 `try/catch`를 제거한다.
- 공통 Model은 두 개 이상의 Feature가 동일한 의미로 사용할 때만 최상위 `models`에 둔다.
- 공통 Service는 Session, Clock, 공유 동작처럼 Feature에 속하지 않는 경우에만 최상위 `services`에 둔다.
- 공통 Widget은 Domain 의미가 없는 Layout과 상태 표현에 한정한다. 디자인 Primitive와 Control은 `design_system`에 둔다.
- Browser 전용 구현은 Platform Adapter 경계 밖으로 노출하지 않는다.

## 추가

- `design_system`: `DESIGN.md` 기반 Token, Theme, 공통 Component
- `core/navigation`: Route 이름, Router 구성, 역할·온보딩 Redirect 규칙
- `core/responsive`: Breakpoint와 공통 Content Constraint
- `app_dependencies.dart`: Service 구현을 한 곳에서 조립하는 Composition Root
- Requirements에 존재하지만 현재 폴더가 없는 Feature Boundary
- Feature별 Service Contract와 Mock Service
- 여러 Mock Service가 일관된 시나리오를 공유할 수 있는 내부용 `MockAppStore`
- 화면 단위 Controller 제공과 생명주기 관리를 위한 얕은 DI Scope

## Architecture Decision Summary

| Decision | 선택 | 이유 |
|---|---|---|
| 전체 구조 | 기존 Feature-first 확장 | 현재 골격을 유지하면서 병렬 UI 개발과 Feature 단위 테스트가 가능함 |
| 계층 깊이 | Page/Widget → Controller → Service | UI 프로젝트에 필요한 최소 책임만 분리함 |
| Service 위치 | 기본적으로 Feature 내부 | 관련 Model과 동작을 한곳에 유지하고 전역 `services` 비대화를 방지함 |
| 의존성 조립 | 앱 Root에서 생성자/Provider 주입 | Page가 Mock 또는 API 구현을 알지 않게 함 |
| 상태 관리 | `ChangeNotifier` + `provider` 권장 | 기존 Controller와 호환되며 학습·도입 비용이 낮음 |
| Routing | `go_router` 권장 | Flutter Web URL, 초대 딥링크, 역할별 Shell과 Redirect를 명시적으로 관리 가능 |
| Mock 일관성 | Service별 Contract + 공유 `MockAppStore` | 배우자 요청 상태와 리포트처럼 Feature 간 반영이 필요한 시나리오 지원 |
| Movement | 현재 코드 보존, MVP Shell에서 격리 | 기존 데모를 깨지 않으면서 Phase 2 범위를 MVP에 섞지 않음 |

# Feature Boundary

## 현재 Feature와 Requirements 비교

| 현재 Feature | 판단 | Requirements 비교 | 설계 결정 |
|---|---|---|---|
| `profile` | 유지·확장 | 프로필 등록/수정뿐 아니라 단계형 온보딩, 요약, 배우자용 조회가 필요 | 사용자 Profile 정보와 Profile 화면을 소유한다. 초대 토큰·수락은 `invitation`으로 분리한다 |
| `condition` | 유지·확장 | 오늘 컨디션 및 예정 활동 입력이 루틴 생성의 연속 입력 흐름 | 컨디션과 예정 활동을 한 Feature에서 관리하되 Model과 Page는 분리한다 |
| `routine` | 유지·역할 명확화 | 통합 Home, 4개 Guide 요약, 생성·Fallback, 완료 집계가 필요 | Home Orchestration과 Daily Routine Summary만 소유한다. Guide 상세 로직은 각 Feature에 둔다 |
| `meal` | 유지·확장 | 추천, 끼니 선택, 재추천, 확정, 공유, 식사 한정 Chat이 필요 | 식사와 식사 재조정 Chat을 함께 소유한다. 범용 AI Assistant로 확장하지 않는다 |
| `movement` | 유지·격리 | 실시간 모션은 Phase 2이며 기존 코드는 제품 화면이 아닌 기술 Demo | 코드를 이동·재작성하지 않는다. MVP Route에서 기본 노출하지 않고 향후 Platform Adapter 정리 대상으로 둔다 |
| `sleep` | 유지·확장 | 추천, 환경 항목 선택·수정, 완료 기록 필요. 실제 가전 실행은 Phase 2 | MVP에서는 추천·선택·기록만 Service Contract로 표현하고 기기 제어 Contract는 만들지 않는다 |

## 추가할 Feature

| Feature | 포함 범위 | 관련 화면 | 경계 설정 이유 |
|---|---|---|---|
| `invitation` | 배우자 초대, 링크 상태, 초대 수락·연결 결과 | SCR-W-14, SCR-H-06 | Profile 데이터 편집과 Deep Link/연결 상태의 생명주기가 다름 |
| `household` | 가사 추천, 직접/가전/가족 분담, 요청·확인·완료 상태 | SCR-W-06, SCR-H-04 | 아내와 파트너가 같은 요청 Model과 상태를 공유해야 함 |
| `health` | 컨디션 기반 건강 가이드와 완료 기록 | SCR-W-08 | Guide 콘텐츠와 수행 상태가 독립적이며 향후 모션 연계 확장점이 있음 |
| `report` | 일일 기록, 컨디션 캘린더, 파트너 아침 리포트와 읽기 전용 날짜 상세 | SCR-W-11, SCR-W-12, SCR-H-01, SCR-H-02 | 동일한 날짜별 기록 Projection을 역할별 UI가 공유함 |
| `notification` | 파트너 앱 내 알림 목록과 읽음 상태 | SCR-H-03 | Push Infra와 분리된 앱 내 Inbox이며 Household/Report로 Routing하는 진입점임 |

## 별도 Feature로 만들지 않는 항목

- **Planned Activity:** 컨디션 다음 단계이며 독립 Navigation 목적이 없으므로 `condition` 내부에 둔다.
- **Meal Chat:** MVP가 식사 재조정으로 한정되므로 `meal` 내부에 둔다.
- **Completion Record:** 각 Guide의 행동이고 `routine`과 `report`에 결과가 반영되는 공통 상태다. 별도 화면 Feature로 만들지 않는다.
- **Partner:** 역할 전용 최상위 Feature를 만들지 않는다. Profile, Report, Notification, Household의 동일 Domain 경계를 역할별 Page가 사용한다.
- **Settings:** Phase 2이고 상세 요구사항이 없으므로 현재는 Feature를 만들지 않는다. Route가 필요해질 때 정의한다.
- **Auth:** 실제 인증 화면과 동작이 정의되지 않았으므로 Feature나 Backend 인증 구조를 임의로 만들지 않는다. Router는 `unknown`, `wife`, `partner` 역할 상태만 받을 수 있는 확장점을 둔다.

## Feature 간 협업 원칙

- `routine` Home은 Meal, Household, Health, Sleep의 Controller를 직접 호출하지 않는다.
- Home에 필요한 4개 영역 요약은 `RoutineService`가 제공하는 `DailyRoutine` Model로 표시한다.
- 상세 화면은 Route Parameter 또는 자신의 Service 조회를 통해 데이터를 얻는다.
- 완료·확정·요청 변경 후에는 해당 Service 결과를 저장한 다음 Routine/Report를 다시 조회한다.
- 여러 Controller를 직접 참조해 상태를 맞추는 방식 대신 Service Contract를 동기화 경계로 사용한다.
- Mock 환경에서는 여러 Service가 하나의 `MockAppStore`를 공유하여 식사 확정, 가사 요청 완료, 리포트 반영이 일관되게 보이도록 한다.
- 실시간 반영이 필요한 가사 요청과 알림은 Service가 `Stream`을 제공할 수 있다. UI는 전송 방식이 Polling인지 Realtime인지 알지 않는다.

# Dependency Direction

## 기본 방향

```text
Page
  ↓
Feature Widget
  ↓
State / Controller
  ↓
Frontend Service Interface
  ↓
Mock Service
  ↓
MockAppStore / Mock Data
```

현재 Backend가 없으므로 의존 흐름은 Mock에서 끝난다. Future API 계층이나 동작하지 않는 `RealService`를 미리 만들지 않는다.

## 각 계층의 책임

| Layer | 책임 | 금지 |
|---|---|---|
| Page | Route 입력 수신, Scaffold/AppShell 구성, Controller Scope 생성 | API 호출, Mock Data 선언, 복잡한 상태 전이 |
| Feature Widget | State를 UI로 표현하고 사용자 Intent를 Controller에 전달 | Service 직접 호출, 다른 Feature Controller 접근, Design Token 하드코딩 |
| State | 화면에 필요한 Immutable 데이터와 Phase 표현 | BuildContext, HTTP/Supabase 객체, Widget 포함 |
| Controller | 입력 검증, 비동기 동작 조정, State 전이, Service 호출 | Endpoint, JSON 파싱, 색상·문구 Layout 결정 |
| Service Interface | 사용자 의도 중심의 Frontend Contract 제공 | HTTP Status, Header, Supabase Row 같은 전송 세부사항 노출 |
| Mock Service | Contract에 맞는 시나리오와 지연·실패·빈 상태 제공 | Widget 참조, Page Navigation 수행 |
| MockAppStore | Mock Service 간 공유되는 In-memory 데이터와 시나리오 상태 보관 | Production 저장소처럼 취급하거나 실제 DB 계약 확정 |

## 허용되는 의존성

```text
app → core, design_system, services, features
feature → core, design_system, shared models/widgets, same feature
design_system → Flutter only
core → Flutter/Dart 및 범용 Package
mock service → same feature model/service + mock store
```

Feature 간 공용 타입이 정말 필요한 경우에만 최상위 `models`로 승격한다. 다른 Feature의 `pages`, `widgets`, `state`를 직접 Import하지 않는다.

## State 형태

Feature별 State는 필요한 상태만 명시한다.

```text
initial
loading
ready(data)
empty
submitting(data)
success(data)
failure(previousData?, message)
```

모든 Feature에 동일한 거대 Base State를 강제하지 않는다. 공통 `AsyncPhase` 정도만 재사용하고, 선택값·진행 단계·요청 상태는 Feature State가 소유한다.

# Backend Replacement Strategy

## 교체 단위

Page와 Component는 Service Interface만 바라본다.

```text
현재
Page → Controller → ProfileService → MockProfileService

향후
Page → Controller → ProfileService → ApiProfileService
```

교체는 `app_dependencies.dart`의 구현 Binding에서만 일어나야 한다.

```dart
// 설계 예시이며 STEP 2에서 실제 파일을 만들지 않는다.
abstract interface class ProfileService {
  Future<PregnancyProfile?> getProfile();
  Future<PregnancyProfile> saveProfile(PregnancyProfileDraft draft);
}

final class AppDependencies {
  AppDependencies({required this.profileService});

  final ProfileService profileService;
}
```

현재는 `AppDependencies.mock()`이 `MockProfileService`를 조립한다. 실제 API가 준비된 뒤에만 `ApiProfileService`를 추가하고 동일 Interface에 연결한다.

## Contract 설계 규칙

- 메서드는 `GET /profile` 같은 Endpoint가 아니라 `getProfile`, `saveCondition`, `completeTask` 같은 사용자 Intent로 이름을 정한다.
- Service Interface는 Frontend가 필요로 하는 Model만 반환한다.
- JSON, HTTP Response, Supabase Client와 Row는 API 구현 내부에서만 사용한다.
- 전송 DTO가 필요해지면 `ApiService` 구현 가까이에 두고 UI Model로 변환한다.
- 오류는 UI가 처리 가능한 공통 실패 종류로 변환한다. 원본 HTTP 예외를 Page까지 전달하지 않는다.
- 날짜 의존 로직은 주입 가능한 Clock을 사용해 오늘/과거 시나리오를 안정적으로 테스트할 수 있게 한다.
- Mock은 정상뿐 아니라 Loading Delay, Empty, Validation Failure, Timeout, Retry Success 시나리오를 제공한다.
- Mock Data는 `mock_data.dart` 또는 Fixture에 모으고 Widget에 직접 작성하지 않는다.
- `MockService`와 향후 `ApiService`가 같은 Contract Test를 통과하도록 Service 행동 규칙을 테스트한다.

## Cross-feature 데이터 일관성

가사 요청 완료가 아내 Home과 Report에 반영되는 것처럼 여러 Feature에 영향을 주는 변경은 다음 구조로 처리한다.

```text
HouseholdController.completeRequest()
  ↓
HouseholdService.completeRequest()
  ↓
MockAppStore 갱신
  ↓
HouseholdService stream 또는 화면 복귀 시 refresh
  ↓
RoutineController / ReportController 재조회
```

전역 Event Bus를 도입하지 않는다. 즉시 동기화가 요구되는 Contract에만 좁은 `Stream`을 사용하고 나머지는 명시적인 `refresh`로 처리한다.

## 실제 Backend 도입 시 변경 범위

변경 대상:

- `core/network`의 API Client와 공통 오류 Mapping
- 각 Feature의 `Api...Service`
- `app_dependencies.dart`의 Binding
- 인증이 확정된 경우 Session/Token Adapter

변경하지 않아야 하는 대상:

- Page Layout
- Feature Widget
- Controller의 사용자 Intent API
- Design System Component
- Routing의 Screen 구조
- Frontend Model의 화면 의미

# Folder Structure

## 최종 제안 구조

이 구조는 한 번에 생성하지 않는다. 해당 Feature를 구현하는 STEP에서 필요한 폴더와 파일만 추가한다.

```text
frontend/lib/
├─ main.dart
├─ app.dart
├─ app_dependencies.dart                 # Service 구현 조립
│
├─ core/
│  ├─ config/
│  │  └─ app_config.dart                 # 유지
│  ├─ constants/                         # 앱 전역 비디자인 상수만
│  ├─ navigation/
│  │  ├─ app_route.dart                  # Route 이름/경로
│  │  └─ app_router.dart                 # Router/Redirect/Shell
│  ├─ network/                           # Future API 도입 전에는 비워 둠
│  ├─ responsive/
│  │  ├─ app_breakpoints.dart
│  │  └─ responsive_content.dart
│  └─ utils/                             # 의미 있는 범용 도구만
│
├─ design_system/
│  ├─ tokens/
│  │  ├─ app_colors.dart
│  │  ├─ app_spacing.dart
│  │  ├─ app_radius.dart
│  │  ├─ app_typography.dart
│  │  └─ app_elevation.dart
│  ├─ theme/
│  │  ├─ app_theme.dart
│  │  └─ app_component_theme.dart
│  └─ components/                        # STEP 3/4에서 확정
│
├─ models/                               # 2개 이상 Feature가 공유하는 타입만
│  ├─ user_role.dart
│  ├─ request_status.dart
│  └─ dated_record_ref.dart
│
├─ services/                             # Feature 중립 Service만
│  ├─ app_session_service.dart
│  ├─ clock.dart
│  └─ mock/
│     └─ mock_app_store.dart
│
├─ widgets/                              # Domain 중립 공통 Widget만
│  ├─ app_shell.dart
│  ├─ async_content.dart
│  └─ page_content.dart
│
└─ features/
   ├─ profile/
   │  ├─ models/
   │  ├─ services/
   │  │  ├─ profile_service.dart
   │  │  └─ mock_profile_service.dart
   │  ├─ state/
   │  ├─ pages/
   │  └─ widgets/
   ├─ invitation/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/
   │  └─ widgets/
   ├─ condition/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/                          # 컨디션 + 예정 활동
   │  └─ widgets/
   ├─ routine/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/                          # 통합 Home
   │  └─ widgets/                        # 4개 Guide summary
   ├─ meal/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/                          # 선택/상세/식사 Chat
   │  └─ widgets/
   ├─ household/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/                          # 아내 Guide + 파트너 요청
   │  └─ widgets/
   ├─ health/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/
   │  └─ widgets/
   ├─ sleep/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/
   │  └─ widgets/
   ├─ report/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/                          # 역할별 Report/Calendar
   │  └─ widgets/
   ├─ notification/
   │  ├─ models/
   │  ├─ services/
   │  ├─ state/
   │  ├─ pages/
   │  └─ widgets/
   └─ movement/                          # 현재 구조와 코드 유지, Phase 2
      ├─ models/
      └─ ...existing files
```

## Feature 내부 최소 구조 규칙

- 단순 Feature는 처음부터 모든 하위 폴더를 만들지 않는다.
- 파일이 1~2개라면 Feature Root에 둘 수 있고, 책임이 늘 때 하위 폴더로 이동한다.
- 한 Page에서만 사용하는 Widget은 Page 파일 내부 Private Widget으로 시작한다.
- 같은 Feature의 둘 이상의 Page에서 재사용되면 `feature/widgets`로 이동한다.
- 서로 다른 Feature에서 재사용되고 Domain 의미가 없을 때만 최상위 `widgets` 또는 `design_system`으로 이동한다.

## Test 구조

```text
frontend/test/
├─ design_system/
├─ core/navigation/
├─ features/
│  └─ {feature}/
│     ├─ state/
│     ├─ services/
│     └─ pages/
└─ helpers/
   ├─ fakes/
   └─ pump_app.dart
```

Production 구조를 기계적으로 모두 복제하지 않고 테스트 대상 기준으로만 디렉터리를 만든다.

# State Management

## 현재 상황

- 별도 State Management Package가 없다.
- 기존 `MovementController`는 `ChangeNotifier`를 사용하고 화면이 직접 Listener를 등록한다.
- MVP는 다수 화면, 역할별 Shell, 공유되는 Profile/Session, 가사 요청 상태와 리포트 반영을 다뤄야 한다.
- 모든 상태를 전역으로 만들 필요는 없지만 Service 주입과 Route 단위 Controller 생명주기를 일관되게 관리할 장치가 필요하다.

## Options

| Option | Pros | Cons | Recommendation |
|---|---|---|---|
| Flutter 기본 `ChangeNotifier` + `ListenableBuilder` + 생성자 주입 | 새 Package 없음, 현재 Movement와 동일, 동작이 명시적 | 중첩 의존성 전달과 Dispose가 반복됨, 역할별 Shell의 공유 상태 제공이 번거로움 | 소규모 Prototype 또는 Package 추가가 불가할 때 사용 가능 |
| `provider` + `ChangeNotifier` | 기존 Controller 재사용, DI와 생명주기 관리 단순, 학습 비용 낮음, `context.select`로 Rebuild 범위 제어 가능 | Mutable State 관리 규칙이 필요하고 깊은 `BuildContext` 의존을 남용할 수 있음 | **MVP 권장**. 현재 구조를 가장 적게 바꾸면서 개발 속도와 테스트성을 확보 |
| Riverpod | BuildContext 없는 DI, Override/Test 용이, Async 상태 조합에 강함 | 현재 코드와 다른 패턴 도입, Provider 정의와 학습 비용, 소규모 Feature에 구조가 무거워질 수 있음 | 복잡한 실시간 상태와 대규모 팀 확장이 확정될 때 재평가 |
| BLoC/Cubit | Event/State 전이가 명확하고 팀 규칙 표준화에 유리 | 파일과 Boilerplate 증가, 현재 MVP 규모와 기존 ChangeNotifier에 비해 도입 비용이 큼 | 현재는 권장하지 않음 |

## Recommendation

`provider`를 추가 Package 후보로 권장하되 STEP 2에서는 설치하지 않는다.

- Service Interface 구현은 앱 Root에서 `Provider<Service>`로 제공한다.
- App Session처럼 여러 Route가 공유하는 최소 상태만 Root Scope에 둔다.
- 입력 Form, Detail, Chat 등 화면 상태는 Route/Page Scope의 `ChangeNotifierProvider`로 제공하고 이탈 시 Dispose한다.
- Controller는 `BuildContext`를 저장하지 않고 생성자에서 Service를 받는다.
- Widget은 `watch`로 전체 Controller를 구독하기보다 `select` 또는 작은 Feature Widget으로 필요한 State만 구독한다.
- 단발성 Navigation/Dialog는 Controller가 Route를 직접 조작하지 않고, Action 결과를 Page가 받아 처리한다.
- `MovementController`는 그대로 두고, 제품 Shell과 연결하는 시점에 Provider Scope로 감싸는 정도만 고려한다.

Package 추가가 승인되지 않으면 같은 Controller/Service Contract를 유지한 채 생성자 주입과 `ListenableBuilder`로 구현할 수 있다. 따라서 상태 관리 Package 선택이 Feature Architecture를 바꾸지는 않는다.

# Routing

## Routing 전략

Flutter Web URL, Browser Back/Forward, 초대 Deep Link, 역할별 Navigation Shell, 온보딩 Redirect가 필요하므로 `go_router`를 Package 후보로 권장한다. STEP 2에서는 설치하거나 Route 코드를 구현하지 않는다.

`Navigator.push`를 Page 곳곳에서 직접 호출하지 않고 Route 이름과 전환 규칙을 `core/navigation`에 모은다. Route Path는 Frontend 내부 식별자이며 실제 Backend Endpoint가 아니다.

## Route Tree 제안

아래 Path는 Architecture 설명을 위한 내부 후보다. 인증·초대 Deep Link 계약이 확정되기 전 외부 URL로 확정하지 않는다.

```text
root
├─ bootstrap                         # Session/Profile 상태 확인 후 Redirect
├─ onboarding
│  ├─ profile                       # SCR-W-01 단계형 Profile
│  └─ invite                        # SCR-W-14
├─ invitation-entry                 # SCR-H-06, 외부 Deep Link 진입 Adapter
│
├─ wife-shell
│  ├─ home                          # SCR-W-04
│  │  ├─ condition                  # SCR-W-02
│  │  ├─ activity                   # SCR-W-03
│  │  ├─ meal                       # SCR-W-05
│  │  ├─ household                  # SCR-W-06
│  │  ├─ health                     # SCR-W-08
│  │  └─ sleep                      # SCR-W-09
│  ├─ movement                      # SCR-W-07, Phase 2/노출 정책 미정
│  ├─ meal-chat                     # SCR-W-10
│  ├─ calendar                      # SCR-W-12
│  │  └─ report/:date               # SCR-W-11
│  ├─ profile                       # SCR-W-01 수정 모드
│  ├─ invite                        # SCR-W-14 재진입
│  └─ settings                      # SCR-W-13, Phase 2/상세 미정
│
└─ partner-shell
   ├─ calendar                      # SCR-H-02, 연결 후 Main
   ├─ report/:date                  # SCR-H-01 또는 선택일 Report
   ├─ notifications                 # SCR-H-03
   ├─ requests/:requestId           # SCR-H-04
   ├─ profile                       # SCR-H-05
   └─ movement                      # SCR-W-07 공용, Phase 2/노출 정책 미정
```

## Route와 Overlay 구분

- 공유 완료, 저장 완료처럼 닫으면 원래 Context로 돌아가는 확인 UI는 Modal이며 Route로 만들지 않는다.
- Profile 단계는 하나의 Wizard Route와 내부 Step State를 기본으로 한다. Browser History에 각 단계를 남겨야 한다는 요구가 확정될 때만 단계별 Route를 사용한다.
- Guide Detail, Report, Partner Request는 새로고침·링크 복원 가치가 있으므로 Named Route로 둔다.
- Home의 4개 Guide Section은 독립 Route가 아니라 동일 Home Page 안의 Feature Widget이다.

## Redirect와 접근 규칙

```text
Session 확인 전          → bootstrap/loading
임산부 + Profile 없음    → onboarding/profile
임산부 + Profile 있음    → wife/home
파트너 + 연결 완료       → partner/calendar
유효 초대 Context        → invitation-entry
권한 없는 역할 Route     → 해당 역할의 Main
알 수 없는 Route         → 접근 가능한 역할 Main 또는 명시적 Not Found
```

- 실제 Login/Signup 화면은 문서에 없으므로 Route를 임의로 추가하지 않는다.
- 초대 Link의 Token 형식, 외부 Domain과 인증 복귀 URL은 향후 계약으로 남긴다.
- 파트너 하단 Navigation 구조는 미정이므로 Route만 독립적으로 설계하고 Shell의 Tab 목록은 STEP 5 전 확정한다.
- 실시간 탭은 MVP 포함 여부가 충돌하므로 Router에서 Phase 2 Route로 격리하고 노출 정책은 확정 전 고정하지 않는다.
- `StatefulShellRoute` 또는 동등한 구조를 사용하더라도 비활성 Movement Tab의 카메라·WebSocket을 반드시 중지해야 한다.

# Architecture Rules

## Source와 범위

1. 기능은 `docs/requirements`, 흐름은 `docs/서비스흐름도`, 시각 규칙은 `DESIGN.md`를 우선한다.
2. `docs/screens` 이미지는 화면 구조와 콘텐츠 참고 자료이며 `DESIGN.md`와 충돌하면 `DESIGN.md`를 따른다.
3. 문서에 없는 화면, 상태, 입력 항목, API Contract를 임의로 확정하지 않는다.
4. Phase 2 기능은 MVP Feature와 Route에서 분리하고 기본 사용자 흐름에 섞지 않는다.

## Dependency

5. 의존 방향은 Page → Feature Widget → State/Controller → Service Interface → 구현체로만 흐른다.
6. Page와 Widget은 `http`, Supabase, WebSocket, JSON, Backend URI를 직접 사용하지 않는다.
7. Controller는 UI Context와 구체 Service 구현을 알지 않는다.
8. Service Interface는 사용자 Intent와 Frontend Model을 사용하며 Endpoint와 전송 Schema를 노출하지 않는다.
9. Mock과 향후 API 구현의 선택은 `app_dependencies.dart`에서만 한다.
10. 다른 Feature의 Page, Widget, Controller를 직접 Import하지 않는다.
11. Feature 간 결과 공유는 Service 재조회 또는 필요한 범위의 Stream으로 처리하고 전역 Event Bus를 만들지 않는다.

## Feature와 File

12. 새 코드는 먼저 기존 Feature에 둘 수 있는지 확인한다.
13. Feature에 속하는 Model, State, Service, Widget은 해당 Feature 안에 둔다.
14. 두 개 이상의 Feature가 같은 의미로 재사용할 때만 최상위 `models`, `services`, `widgets`로 승격한다.
15. 모든 Feature에 동일한 폴더를 미리 생성하지 않고 실제 파일이 생길 때만 구조를 추가한다.
16. 작은 Widget은 Page의 Private Widget으로 시작하고 재사용 근거가 생기면 이동한다.
17. 화면 파일 하나에 대규모 상태 처리, Mock Data, Parsing Logic을 함께 작성하지 않는다.

## State

18. 화면이 필요로 하는 Loading, Ready, Empty, Submitting, Success, Error 상태를 Feature State로 명시한다.
19. State는 Immutable하게 교체하고 외부에서 Controller 필드를 직접 변경하지 않는다.
20. 비동기 요청 완료 후 Controller가 Dispose됐을 가능성을 고려한다.
21. Error는 사용자에게 보여줄 메시지와 개발 진단 정보를 구분하고 민감정보를 UI에 노출하지 않는다.
22. 전역 상태는 Session, 역할, 공통 Service처럼 실제로 공유되는 최소 범위에 한정한다.

## UI와 Design System

23. Feature Widget은 색상, TextStyle, 간격, Radius를 직접 정의하지 않고 Design Token과 공통 Component를 사용한다.
24. App Shell, Responsive Constraint, Loading/Empty/Error UI를 화면별로 중복 구현하지 않는다.
25. 공통 Component에 Feature 비즈니스 규칙을 넣지 않는다.
26. `DESIGN.md`의 반응형·접근성 규칙은 Architecture의 횡단 관심사로 취급한다.

## Backend와 Mock

27. 현재는 Mock Service만 구현하며 빈 `ApiService`나 동작하는 것처럼 보이는 가짜 Endpoint 코드를 만들지 않는다.
28. Mock Fixture를 Widget 내부에 두지 않고 Service 또는 Fixture 파일에서 관리한다.
29. 실제 API 도입 시 Transport DTO와 Mapping은 `ApiService` 내부 경계에 둔다.
30. Backend 오류, 지연, 빈 결과도 Service Contract와 UI State를 통해 표현한다.
31. Frontend에 Service Role Key, LLM Key 또는 기타 Secret을 두지 않는다.

## Routing과 Platform

32. Route 이름과 역할 접근 규칙을 중앙화하고 문자열 Path를 Widget에 흩어놓지 않는다.
33. Modal 결과와 Page Navigation을 구분한다.
34. Browser 전용 코드는 Platform Adapter에 격리하고 공용 Controller가 이를 Import하지 않게 한다.
35. Camera, Stream, Animation Controller 등 Resource는 화면 이탈·탭 비활성·앱 Background에서 정리한다.

## 품질과 변경 관리

36. Controller와 Service는 Constructor Injection으로 단위 테스트 가능하게 만든다.
37. Service 구현 교체를 검증할 Contract Test와 주요 Route Redirect Test를 둔다.
38. 기존 `movement` 코드는 Phase 2 작업 전 불필요하게 이동하거나 전면 Refactor하지 않는다.
39. Package 추가는 목적과 대안, 영향 범위를 문서화하고 승인된 구현 단계에서만 수행한다.
40. Architecture 변경이 기능 설명이나 실행 방법에 영향을 줄 때만 `README.md`와 `guide.md`를 함께 갱신한다.

