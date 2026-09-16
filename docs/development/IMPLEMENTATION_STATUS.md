# Frontend Implementation Status

## Summary

현재 Flutter Frontend에는 Design Token, Theme, 공통 Skeleton Component, 제품 화면 20개와 서비스 흐름 기반 Router가 구현되어 있다. 각 제품 화면은 실제 UI가 아닌 `SKELETON` 상태이며 Mock Service와 Feature Controller는 아직 없다. 기존 Web 전용 모션 인식 데모는 제품용 Phase 2 Placeholder와 분리해 보존한다.

이 문서는 제품 UI Task의 상태판이다. 작업자는 시작할 때 `Owner`, `Status`, `Branch`를 갱신하고 Handoff 시 해당 Task 문서의 `Handoff Output`을 작성한다. Status는 `Todo`, `Doing`, `Review`, `Done`, `Blocked` 중 하나만 사용한다.

## Screen Status

| Task | Screen | Feature | Owner | Status | Branch | Route | Notes |
|---|---|---|---|---|---|---|---|
| UI-001 | W-PROFILE-001 임산부 프로필 설정 | profile | Unassigned | Todo | - | `/onboarding/profile`, `/wife/profile` | SKELETON; create/edit 진입 맥락 구현 |
| UI-002 | W-INVITE-001 배우자 초대 | invitation | Codex | Done | - | `/onboarding/invite`, `/wife/invite` | Mock 링크·복사·공유 결과·onboarding/manual 복귀 구현 |
| UI-003 | H-INVITE-001 초대 수락 | invitation | Codex | Done | - | `/invitation-entry?token=` | Mock Token 예외·연동 구현, 외부 Domain/인증 복귀 미정 |
| UI-004 | W-COND-001 오늘의 컨디션 | condition | Unassigned | Todo | - | `/wife/home/condition?mode=` | SKELETON; create/edit 분기 구현 |
| UI-005 | W-TASK-001 오늘 예정 활동 | condition | Codex | Done | - | `/wife/home/activity` | 9종 복수 선택·직접 입력·local 저장·Mock 생성 구현 |
| UI-006 | W-ROUTINE-001 통합 홈 | routine | Unassigned | Todo | - | `/wife/home` | SKELETON; Wife Shell 연결 |
| UI-007 | W-MEAL-001 식사 가이드 | meal | Unassigned | Todo | - | `/wife/home/meal` | SKELETON |
| UI-008 | W-CHAT-001 식사 재조정 채팅 | meal | Codex | Done | - | `/wife/meal-chat` | 누적 메시지·추천 프롬프트·Mock AI 응답·Meal 적용 Flow 구현 |
| UI-009 | W-HEALTH-001 건강 가이드 | health | Unassigned | Todo | - | `/wife/home/health` | SKELETON |
| UI-010 | W-SLEEP-001 수면 가이드 | sleep | Unassigned | Todo | - | `/wife/home/sleep` | SKELETON |
| UI-011 | W-HOUSE-001 가사 가이드 | household | Unassigned | Todo | - | `/wife/home/household` | SKELETON; Partner 화면 직접 이동 제거 |
| UI-012 | H-REQUEST-001 파트너 가사 요청 | household | Codex | Done | - | `/partner/requests/:requestId` | 요청 확인·완료·결과 안내 local 상태 구현 |
| UI-014 | H-NOTI-001 알림 | notification | Codex | Done | - | `/partner/notifications` | Mock Inbox·읽음 처리·목적 Route 연결, Push 제외 |
| UI-015 | W-REPORT-001 Daily 리포트 | report | Unassigned | Todo | - | `/wife/calendar/report/:date` | SKELETON; date 전달 구현 |
| UI-016 | W-CAL-001 컨디션 캘린더 | report | Unassigned | Todo | - | `/wife/calendar` | SKELETON |
| UI-017 | H-REPORT-001 파트너 아침 리포트 | report | Codex | Done | - | `/partner/report/:date` | 날짜별 공유 요약·Request 진입·상태 UI 구현 |
| UI-018 | H-CAL-001 파트너 캘린더 | report | Unassigned | Todo | - | `/partner/calendar` | SKELETON; Partner Main/Shell 연결 |
| UI-019 | 요구사항 ID 미정 설정 | settings | Unassigned | Blocked | - | `/wife/settings` | SKELETON; 서비스 흐름상 비활성·상세 요구사항 미정 |
| UI-020 | W-MOTION-001 공유 실시간 모션 | movement | Unassigned | Blocked | - | `/wife/movement`, `/partner/movement` | SKELETON / Phase 2; 기존 Web Demo 별도 보존 |

## Shared Components

Skeleton 분업 기반에 필요한 최소 공통 Component가 구현되어 있다. 상세 Variant와 Domain Component는 화면 Task에서 추가한다.

| Component | 존재 여부 | 현재 사용 위치 | 재사용 가능 여부 | 수정 주의사항 |
|---|---|---|---|---|
| `AppButton` | 있음 | Skeleton Navigation | 전체 제품 UI | Foundation Owner만 API 변경 |
| `AppInput`, `SelectionCard` | 있음 | Design System | Profile, Condition, Activity, Sleep | Semantics와 오류 계약 유지 |
| `AppCard` | 있음 | Skeleton 상태 안내 | 제품 UI 전반 | Feature 비즈니스 규칙을 넣지 않음 |
| `AppProgressMetric`, `AppSkeleton` | 없음 | - | Condition, Loading 상태 | 색만으로 상태를 표현하지 않음 |
| `ResponsivePageContent` | 없음 | - | 모든 Page | `core/responsive`에 동명 구현을 중복 생성하지 않음 |
| `TopAppBar`, `AppBottomNavigation` | 있음 | 역할별 Skeleton Shell | 역할별 화면 | Wife 4개, Partner 문서 명시 최소 2개 Tab 유지 |
| `LoadingState`, `EmptyState`, `ErrorState` | 없음 | - | 비동기 화면 | 범용 상태 Wrapper로 과도하게 합치지 않음 |
| `CategoryBadge`, `StatusBadge`, `GuideTaskCard` | 없음 | - | Routine, Guide, Report | `AppChip`과 Domain 상태 Mapping 책임을 구분 |
| `ProductSkeletonScreen` | 있음 | 제품 화면 20개 | 상세 UI 구현 전 Navigation 검증 | Feature 상세 UI로 점진 교체 |
| `_PostureBadge`, `MovementOverlayPainter` | 있음 | `features/movement` 데모 | 공통화하지 않음 | Backend enum/Canvas에 결합된 데모 전용 구현 보존 |

Component의 상세 Props와 Variant는 `04_component_system.md`를 단일 기준으로 사용한다.

## Design System

| 영역 | 상태 | 현재 코드 | 구현 기준 |
|---|---|---|---|
| Colors | 구현 | `AppColors` | DESIGN.md Product Palette |
| Typography | 구현 | `AppTypography` | DESIGN.md Type Scale |
| Spacing | 구현 | `AppSpacing` | 4pt Grid |
| Radius | 구현 | `AppRadius` | Component Hierarchy |
| Elevation | 미구현 | Material 기본 Card | `AppElevation` |
| Responsive Breakpoints | 미구현 | 제품 Page 없음 | `AppBreakpoints` |
| Theme | 구현 | `AppTheme.light` | 상세 Component Theme 확장 가능 |

Token 값과 Flutter Mapping은 `DESIGN.md`, `03_design_system.md`를 따른다. Token 파일을 여러 Feature에서 각자 만들지 않는다.

## Mock Services

현재 제품용 Mock Data, Service Interface, Mock Service, App Dependency 조립은 구현되어 있지 않다. 기존 `MovementController`의 `CameraFrameSource`와 `LiveTransport`는 테스트 Fake 주입 경계지만 제품 Mock Service 체계는 아니다.

구현 규칙:

```text
Page → Feature Widget → State/Controller → Service Interface → MockService
```

- Mock Fixture를 Page나 Widget에 직접 작성하지 않는다.
- 빈 `ApiService` 또는 임의 Endpoint를 만들지 않는다.
- Service 선택은 향후 `app_dependencies.dart` 한 곳에서 수행한다.
- Feature 간 공유 결과는 공통 Mock Store/Service 재조회 또는 필요한 범위의 Stream으로 전달한다.

## Known Issues

- Flutter 기본 Navigator 기반 중앙 Router를 사용한다. `go_router`, `provider`는 설치하지 않았다.
- 내부 제품 Route, Not Found, 동적 Parameter 파싱은 구현됐지만 실제 Session 기반 역할 Redirect/Guard는 미구현이다.
- 외부 초대 Domain과 로그인/가입 복귀 URL 계약은 미정이다.
- Android/iOS 정식 플랫폼 프로젝트가 저장소에 없고 `dart:html` Adapter 때문에 현재 앱은 Web 전용이다.
- `.env`가 Flutter asset이라 파일이 없으면 실행/빌드가 실패한다.
- Partner Bottom Navigation은 문서에 명시된 Calendar/Realtime 최소 항목만 제공한다. 설정 상세와 초대 인증 복귀 계약은 미정이다.
- 실시간 모션 제품 화면은 MVP 제외다. 기존 Demo는 단일 세션 Backend와 실제 브라우저 수동 검증에 의존한다.
- Backend가 없는 제품 Feature의 Loading/Empty/Error/성공 상태는 아직 Mock으로 재현되지 않는다.

## Integration Notes

충돌 위험이 높은 공통 파일은 Integration Owner 한 명만 수정한다.

| 파일/영역 | 위험 | 규칙 |
|---|---|---|
| `frontend/lib/app.dart` | 앱 진입, Theme, Dependency 조립 동시 변경 | Integration Owner 전용 |
| `frontend/lib/routing/app_router.dart` | 모든 Feature Route 등록과 Parameter 파싱 | Integration Owner 전용; Feature는 Screen Builder만 제공 |
| `frontend/lib/routing/route_names.dart` | Route 이름·Path 계약 | 임의 변경 금지; 변경 시 ROUTE_MAP/Test 동시 갱신 |
| `frontend/lib/routing/route_context.dart` | 진입 모드·역할·Bootstrap 상태 계약 | 실제 Session Model과 혼합하지 않음 |
| `frontend/lib/core/theme/**` 또는 `design_system/tokens/**` | 전 화면 시각 영향 | Foundation 완료 후 API Freeze |
| `frontend/lib/design_system/components/**` | Props 변경 시 다수 Feature 영향 | Shared Component Owner 리뷰 필수 |
| `frontend/lib/widgets/**` | Shell/상태 UI 중복과 충돌 | 새 공통화 전 기존 목록 확인 |
| `frontend/lib/core/di/app_dependencies.dart` | Mock 구현 선택과 전역 Store | Integration Owner 전용 |
| `frontend/pubspec.yaml`, `pubspec.lock` | Package/Asset 충돌 | Integration Owner만 변경, 사전 승인 필요 |
| `frontend/lib/features/movement/**` | 동작 중인 Web 데모 회귀 | UI-020 전에는 수정하지 않음 |

Feature Branch는 자신의 `features/<feature>/**`와 관련 Test를 우선 수정한다. 공통 변경이 필요하면 별도 작은 Commit으로 분리해 Integration Owner가 먼저 병합한다.

## Dependency Graph

```mermaid
flowchart LR
  F[Foundation: Token + Shared Components] --> U1[UI-001 Profile]
  U1 --> U2[UI-002 Wife Invite]
  U2 --> U3[UI-003 Invite Acceptance]
  U1 --> U4[UI-004 Condition]
  U4 --> U5[UI-005 Activity]
  U1 --> U6[UI-006 Home/Shell]
  U4 --> U6
  U5 --> U6
  U6 --> U7[UI-007 Meal]
  U7 --> U8[UI-008 Meal Chat]
  U6 --> U9[UI-009 Health]
  U6 --> U10[UI-010 Sleep]
  U2 --> U11[UI-011 Household]
  U6 --> U11
  U11 --> U12[UI-012 Partner Request]
  U3 --> U14[UI-014 Notifications]
  U12 --> U14
  U7 --> U15[UI-015 Daily Report]
  U9 --> U15
  U10 --> U15
  U12 --> U15
  U15 --> U16[UI-016 Wife Calendar]
  U3 --> U17[UI-017 Partner Report]
  U12 --> U17
  U15 --> U17
  U14 --> U18[UI-018 Partner Calendar]
  U16 --> U18
  U17 --> U18
  P2[Phase 2 Requirements] --> U19[UI-019 Settings]
  P2 --> U20[UI-020 Movement Product UI]
```

Foundation은 별도 화면 Task가 아니라 UI-001 착수 전 Integration Owner가 `03_design_system.md`와 `04_component_system.md`의 최소 세트를 구현·검토하는 선행 작업이다.

## Parallelizable Tasks

| Wave | 병렬 가능 Task | 조건 |
|---|---|---|
| 0 | Foundation / Route skeleton | 두 작업자가 나누지 않고 Integration Owner가 순차 확정 |
| 1 | UI-002와 UI-004 | UI-001 완료 후 서로 다른 Feature에서 진행 |
| 2 | UI-003와 UI-005 | 각각 UI-002, UI-004 완료 후 진행 |
| 3 | UI-007, UI-009, UI-010, UI-011 | UI-006 완료 및 공통 Component API Freeze 후 Feature별 병렬 진행 |
| 4 | UI-008와 UI-012 | 각각 UI-007, UI-011 완료 후 병렬 진행 |
| 5 | UI-014와 UI-015 | UI-014용 Report Route Placeholder 계약을 Integration Owner가 먼저 제공 |
| 6 | UI-016과 UI-017 | UI-015 완료 후 Wife/Partner Report Slice로 병렬 진행 |
| 7 | UI-018 | UI-014, UI-016, UI-017 통합 후 진행 |
| Phase 2 | UI-019, UI-020 | 요구사항과 정책 확정 전 착수 금지 |

## Conflict-prone Tasks

- UI-001: 최초 Foundation, Theme와 Dependency 조립을 함께 건드릴 가능성이 높다.
- UI-006: `app.dart`, Router, Wife Shell, Bottom Navigation의 Integration 지점이다.
- UI-011/UI-012/UI-015/UI-017: 동일한 Household Request와 Report Projection Mock Store를 공유한다.
- UI-014/UI-017/UI-018: Partner Shell, Notification badge, Partner Main Route에서 충돌할 수 있다.
- UI-015/UI-016/UI-017/UI-018: `features/report/**`를 공유하므로 파일 단위 Owner를 먼저 나눈다.
- UI-020: 기존 `features/movement/**`, Shell Tab, Lifecycle 정리를 동시에 건드린다.

## Recommended Ownership

### Developer A — Integration Owner / Identity & Daily Core

- Foundation Token, Theme, Design System Component와 Shared Shell
- UI-001 Profile
- UI-002 Wife Invitation
- UI-003 Invitation Acceptance
- UI-004 Condition
- UI-005 Planned Activity
- UI-006 Home 및 Navigation Integration
- 공통 파일: `app.dart`, Router, `app_dependencies.dart`, `pubspec.yaml`

### Developer B — Care & Record Vertical Slices

- UI-007 Meal
- UI-008 Meal Chat
- UI-009 Health
- UI-010 Sleep
- UI-011/UI-012 Household Request 양쪽 흐름
- UI-014 Notification
- UI-015~UI-018 Report/Calendar

Developer B는 Wave 0~2 동안 Task 문서 검토, Feature Model/Fixture 초안 또는 공통 Component Review를 수행하고, UI-006 Integration Contract가 Freeze된 뒤 Guide Slice를 병렬 구현한다. UI-019/UI-020은 Phase 2 결정 후 별도 재배정한다.

## Shared File Ownership

1. Developer A를 기본 Integration Owner로 지정한다. 팀 합의로 바꿀 수 있지만 동시에 두 명이 맡지 않는다.
2. Integration Owner만 `app.dart`, Router 등록부, Theme/Token, `app_dependencies.dart`, `pubspec.yaml`을 직접 병합한다.
3. Developer B가 공통 변경을 필요로 하면 Feature Branch에서 임의 수정하지 않고 필요한 API와 사용 사례를 먼저 제안한다.
4. Shared API 변경은 작은 선행 PR로 분리하고 두 작업자가 반영한 뒤 Feature PR을 진행한다.
5. Route와 Model 이름을 바꿀 때 관련 Task, `ROUTE_MAP.md`, 상태표를 같은 변경에서 갱신한다.
6. Integration Owner는 각 Feature가 제공한 Route Builder를 중앙 Router에 연결하고 역할 Redirect/Browser Back 회귀를 검증한다.
