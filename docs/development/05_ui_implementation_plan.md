# 화면 구현 계획 원칙

- 본 계획은 `01_frontend_analysis.md`, `02_frontend_architecture.md`, `03_design_system.md`, `04_component_system.md`, 최신 기획 문서와 서비스 흐름도를 기준으로 한다.
- `docs/screens/**` 이미지는 정보 구조와 콘텐츠 배치 참고 자료이며 시각 규칙이 충돌하면 `DESIGN.md`를 따른다.
- 모든 화면은 Page → Feature Widget → Controller/State → Service Interface → Mock Service 방향을 유지한다.
- Mock Data는 Widget에 직접 작성하지 않고 Feature의 Mock Service와 Fixture에서 제공한다.
- 한 번에 전체 화면을 구현하지 않고 Foundation과 Shared Component를 검증한 뒤 Task 단위로 진행한다.
- 각 화면은 `docs/requirements/04_1_기능요구사항명세서.md`의 대표 요구사항 ID로 구분하고, 상세 범위에는 연결된 `W-*`·`H-*` ID를 모두 기록한다. 별도 Screen ID는 만들지 않는다.
- Partner Navigation은 Route Map에 명시된 Calendar/Realtime 최소 항목만 사용하고, 인증 Redirect·실시간 기능 노출·수면 가전 실행처럼 미정인 동작은 임의로 확정하지 않는다.

# W-PROFILE-001 — 임산부 프로필 설정

## 대표 요구사항 ID

`W-PROFILE-001`

## Screen Name

임산부 프로필 등록/수정

## Purpose

임신 주차와 개인화 Guide에 필요한 Profile을 단계적으로 등록하고 이후 수정한다.

## User Goal

신체적·인지적 부담 없이 정보를 입력하고, 저장 전 내용을 확인한다.

## Layout

```text
Page
├─ AppTopBar
├─ ResponsivePageContent(form)
│  ├─ Profile progress
│  ├─ ProfileWizardForm
│  │  ├─ Question title / supporting copy
│  │  ├─ Current step input or selection
│  │  └─ Helper / validation message
│  ├─ ProfileSummary                    # 마지막 확인 단계
│  └─ Primary action
└─ Optional sticky action area          # 짧은 viewport만
```

## Components

`AppTopBar`, `ResponsivePageContent`, `ProfileWizardForm`, `ProfileSummary`, `AppTextField`, `AppSelectionCard`, `AppButton`, `AppBanner`

## Data

- Mock `PregnancyProfileDraft`: 예정일 또는 마지막 생리 시작일, 신체 정보, 출산 경험, 다태 여부, 문서에 정의된 건강 정보
- Mock 저장 Profile과 계산된 임신 주차
- 입력 Option은 기획에서 확정된 항목만 사용하며 미정 Option은 구현 전 확인한다.

## UI State

- Default: 현재 Step과 저장된 Draft 표시
- Loading: 수정 모드의 기존 Profile 조회
- Error: Field Validation 또는 저장 실패
- Selected: 선택형 항목의 현재 값
- Disabled: 필수값 미충족 또는 저장 중 다음/완료 Action

## Interaction

- Input: 날짜·수치·선택값 입력
- Tap/Keyboard: 다음, 이전, 수정 가능한 Summary Section
- Hover/Focus: 모든 Input과 Action에 명확한 상태
- Transition: Step 간 160~220ms, Reduced Motion에서는 즉시 전환
- Scroll: 200% Text와 짧은 Viewport에서 전체 Form Scroll

## Navigation

- 최초 진입: Bootstrap에서 Profile 없음
- 최초 저장 성공: W-INVITE-001
- 수정 진입: 전역 Profile Menu
- 수정 저장 성공: 이전 화면
- Back: Draft 손실 정책은 STEP 5 이후 Interaction 구현 전 확인

## Responsive

- Mobile: Single Column, 20px Padding, Primary CTA Full Width
- Tablet: 최대 560px 중앙 정렬, 짧은 선택지만 조건부 2열
- Desktop: 최대 560px, 과도하게 넓히지 않고 Keyboard 흐름 유지

## Accessibility

- Focus: 시각 순서와 동일한 Step/Field/Action 순서
- Keyboard: Tab, Shift+Tab, Enter/Space, 날짜 입력 가능
- Semantics: Step n/6, Field Label, 필수 여부, 오류를 Field와 연결

## Definition of Done

- 최초 등록과 수정 모드가 동일 Page 구조를 재사용한다.
- 단계 이동, Validation, Loading/Error, 저장 중 중복 실행 방지가 동작한다.
- 200% Text에서 잘림이 없고 최소 44×44 Target을 충족한다.
- Profile 저장 로직은 Mock Service에만 연결된다.

# W-INVITE-001 — 배우자 초대

## 대표 요구사항 ID

`W-INVITE-001`

## Screen Name

배우자 초대하기

## Purpose

파트너 연결의 가치와 현재 상태를 설명하고 Mock 초대 링크의 공유 흐름을 제공한다.

## User Goal

배우자를 지금 초대하거나 안전하게 나중으로 미룬다.

## Layout

```text
Page
├─ AppTopBar
├─ ResponsivePageContent(form)
│  ├─ Intro banner
│  ├─ Benefit list
│  ├─ PartnerInvitePanel
│  │  ├─ Invite link preview
│  │  └─ Copy / share feedback
│  └─ Primary share + secondary later actions
└─ PartnerShareResultDialog             # 공유 결과 Overlay
```

## Components

`AppTopBar`, `ResponsivePageContent`, `PartnerInvitePanel`, `AppBanner`, `AppButton`, `PartnerShareResultDialog`

## Data

- Mock 초대 상태: 미발급, 발급 중, 공유 가능, 공유 완료, 연결 완료, 오류
- 표시용 Mock Link Label; 실제 Token 형식이나 외부 Domain은 확정하지 않는다.

## UI State

- Loading: 링크 생성 중
- Default: 링크와 Benefit 표시
- Error: 생성·복사·공유 실패와 재시도
- Disabled: 생성/공유 중 중복 Action

## Interaction

- Tap/Keyboard: 링크 복사, 공유, 나중에
- Hover/Focus: Action 상태
- Transition: 공유 결과 Dialog

## Navigation

- 최초 Profile 등록 성공 또는 미연결 상태의 Profile Menu에서 진입
- 나중에/공유 완료: W-ROUTINE-001
- 연결 완료 상태: 초대 Action을 제거하고 상태만 표시하거나 이전 화면으로 복귀

## Responsive

- Mobile: Action Stack 또는 충분한 폭에서 2개 Row
- Tablet/Desktop: 최대 560px, Dialog 최대 480px

## Accessibility

- Focus: 복사 → 공유 → 나중에 순서
- Keyboard: 모든 Action 실행, Dialog Focus Trap
- Semantics: 링크 Label, 복사 완료 Live 안내, 연결 상태 Text

## Definition of Done

- 링크 생성·공유·나중에·오류 상태가 Mock으로 재현된다.
- 실제 Endpoint나 공유 Channel을 임의로 확정하지 않는다.
- 공유 성공을 색만이 아닌 Icon/Text로 알린다.

# W-COND-001 — 오늘의 컨디션

## 대표 요구사항 ID

`W-COND-001`

## Screen Name

오늘의 컨디션 체크

## Purpose

루틴 생성에 사용할 당일 입덧·통증·피로·기분 등의 상태를 짧게 기록한다.

## User Goal

60초 이내에 오늘 상태를 이해하기 쉬운 단계로 입력한다.

## Layout

```text
Page
├─ AppTopBar
├─ ResponsivePageContent(form)
│  ├─ ConditionSummaryBanner(date/week)
│  ├─ ConditionSelector
│  │  ├─ Nausea ProgressMetric
│  │  ├─ BodyPainSelector
│  │  ├─ Fatigue ProgressMetric
│  │  └─ Mood ProgressMetric
│  ├─ Validation / error
│  └─ Primary next action
```

## Components

`AppTopBar`, `ResponsivePageContent`, `ConditionSummaryBanner`, `ConditionSelector`, `BodyPainSelector`, `AppProgressMetric`, `AppButton`

## Data

- Mock 날짜, 임신 주차, 저장된 오늘 컨디션
- Mock Metric Label/단계; 정확한 Option과 Scale은 요구사항 확정값만 사용

## UI State

- Default: 미입력 또는 수정 모드 저장값
- Loading: 저장된 오늘 값 조회
- Error: 필수 Metric 누락, 저장 실패
- Selected: 단계별 값과 Text 상태
- Disabled: 필수 입력 미완료/저장 중

## Interaction

- Tap/Keyboard: 5단계 Meter와 부위별 값 선택
- Input: 문서에서 허용한 보조 입력
- Scroll: Metric 목록
- Transition: 저장 성공 후 예정 활동

## Navigation

- W-ROUTINE-001의 컨디션 CTA 또는 다시 입력 Action에서 진입
- 저장 성공: W-ACT-001
- 수정 취소: W-ROUTINE-001

## Responsive

- Mobile: 모든 Metric Single Column
- Tablet/Desktop: 최대 560px, Label 가독성을 위해 기본 Single Column 유지

## Accessibility

- Focus: Metric별 Label → Segment 순서
- Keyboard: Arrow Key로 값 변경, Tab으로 다음 Metric
- Semantics: 현재 단계와 `좋아요/보통/심해요` Text를 함께 읽음

## Definition of Done

- 입력·수정·Validation·저장 실패 상태가 구현된다.
- 색 없이도 모든 단계가 구분된다.
- Mock Service 저장 후 다음 화면과 Home State가 갱신된다.

# W-ACT-001 — 오늘 예정 활동

## 대표 요구사항 ID

`W-ACT-001`

## Screen Name

오늘 예정 활동 선택

## Purpose

가사 및 생활 Guide 조정에 사용할 오늘의 활동을 기록한다.

## User Goal

예정된 활동을 빠르게 선택하고 루틴 생성을 시작한다.

## Layout

```text
Page
├─ AppTopBar
├─ ResponsivePageContent(form)
│  ├─ Question title / supporting copy
│  ├─ PlannedActivitySelector
│  │  └─ AppSelectionCard list/grid
│  ├─ Helper / error
│  └─ Primary generate action
```

## Components

`AppTopBar`, `ResponsivePageContent`, `PlannedActivitySelector`, `AppSelectionCard`, `AppButton`, `ErrorState`

## Data

- Mock 활동 Option과 선택값
- 선택 Option은 문서에서 확정된 항목만 사용한다.

## UI State

- Default: 미선택 또는 저장값
- Selected: 단일/복수 선택 결과
- Error: 저장·루틴 생성 시작 실패
- Disabled: 유효 조건 미충족/제출 중

## Interaction

- Tap/Keyboard: Card 선택·해제
- Hover/Focus: 선택 가능한 Card 강조
- Transition: 생성 중 Home으로 이동

## Navigation

- W-COND-001 저장 후 진입
- 제출 성공: W-ROUTINE-001의 Routine Generation 상태
- Back: W-COND-001

## Responsive

- Mobile: Single Column 우선
- Tablet/Desktop: 짧은 Option만 2열, 최대 560px

## Accessibility

- Focus/Keyboard: Card 순서와 Space/Enter 선택
- Semantics: 복수 선택 여부, 선택됨/선택 안 됨

## Definition of Done

- 선택·해제·Disabled·Error 상태가 동작한다.
- 다음 화면에 선택 결과가 Mock Service를 통해 반영된다.
- 200% Text에서 선택 Card가 겹치지 않는다.

# W-ROUTINE-001 — 통합 홈

## 대표 요구사항 ID

`W-ROUTINE-001`

## Screen Name

AI 하루 루틴 홈

## Purpose

임신 주차와 오늘 상태를 먼저 보여주고, 입력 완료 후 4개 Guide를 한 화면에 제공한다.

## User Goal

오늘 필요한 행동을 한눈에 이해하고 각 Guide로 이동한다.

## Layout

```text
AppShell
├─ AppTopBar(title/profile menu)
├─ ResponsivePageContent(dashboard)
│  ├─ PregnancyWeekHero
│  ├─ Condition CTA                         # 미입력일 때만
│  ├─ RoutineGenerationState               # 생성 중/실패일 때
│  └─ DailyCareSection                     # 생성 완료 후
│     ├─ SectionHeader
│     ├─ RoutineGuideCard × 4
│     └─ Finish day action
└─ AppBottomNavigation
```

## Components

`AppShell`, `AppTopBar`, `ResponsivePageContent`, `PregnancyWeekHero`, `RoutineGenerationState`, `DailyCareSection`, `RoutineGuideCard`, `AppBottomNavigation`, `ProfileMenu`

## Data

- Mock 사용자명, 임신 주차, 주차별 Tip
- Mock 오늘 컨디션 입력 여부와 Routine 생성 상태
- Mock Meal/Household/Health/Sleep Summary와 완료 상태
- Mock Fallback Routine

## UI State

- Default: 컨디션 미입력 시 Hero와 CTA만 표시
- Loading: 저장된 오늘 Routine 조회 또는 생성 중 Skeleton
- Empty: Profile은 있으나 오늘 입력 없음; 별도 Empty Card 대신 CTA 사용
- Error: Fallback Guide와 정확도 저하 안내, 재시도
- Selected: Bottom Navigation Home
- Disabled: 생성 중 Guide와 하루 마치기 Action

## Interaction

- Tap/Keyboard: 컨디션 입력, Profile Menu, Guide, 하루 마치기
- Hover/Focus: Guide Card와 Navigation
- Scroll: Hero 아래 4개 Guide
- Transition: 생성 상태 → Guide 표시 240~300ms 이하

## Navigation

- Profile 완료 사용자 기본 진입
- 컨디션 CTA → W-COND-001
- 각 Guide → W-MEAL-001, W-HOUSE-001, W-HEALTH-001, W-SLEEP-001
- Chat Tab → W-CHAT-001, Calendar Tab → W-CAL-001
- Finish Day → W-REPORT-001
- Realtime Tab 정책은 Phase 2 범위 확인 전 확정하지 않는다.

## Responsive

- Mobile: Single Column, Bottom Navigation
- Tablet: 최대 680~720px, Guide는 기본 Single Column
- Desktop: 최대 720px, Main Task Single Column, Secondary Summary만 조건부 2열

## Accessibility

- Focus: AppBar → Hero CTA → Guide 순서 → Navigation
- Keyboard: Card/Navigation 활성화, Menu 탐색
- Semantics: 임신 주차, 생성 진행, Guide별 완료 상태 Live 안내

## Definition of Done

- 미입력, 생성 중, 생성 성공, 저장 Routine, Fallback 상태가 모두 재현된다.
- 미입력 상태에서는 Guide 영역이 표시되지 않는다.
- Home에서 API/Mock 구현을 직접 참조하지 않는다.

# W-MEAL-001 — 식사 가이드

## 대표 요구사항 ID

`W-MEAL-001`

## Screen Name

식사 가이드

## Purpose

컨디션 기반 끼니별 추천을 제공하고 수락·재선택·기록·공유로 연결한다.

## User Goal

추천 근거와 주의사항을 이해하고 먹을 Menu를 부담 없이 결정한다.

## Layout

```text
Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ ConditionSummaryBanner
│  ├─ MealPeriodSelector
│  ├─ MealRecommendationCard
│  │  ├─ Visual / menu info
│  │  ├─ Evidence / nutrition chips
│  │  └─ accept / rechoose / share actions
│  └─ MealCautionSection
└─ AppBottomNavigation when shell context
```

## Components

`ConditionSummaryBanner`, `MealPeriodSelector`, `MealRecommendationCard`, `MealCautionSection`, `AppChip`, `AppButton`, `PartnerShareResultDialog`

## Data

- Mock 끼니별 추천, 이유, 영양 목적, 주의 항목, 허용 범위
- Mock 수락·공유 상태
- 실제 식사 이미지 Asset이 없으면 스타일이 다른 임의 이미지를 섞지 않는다.

## UI State

- Loading: 추천 Skeleton
- Empty: 추천 없음과 다시 시도 안내
- Error: 추천 실패/재시도
- Selected: 현재 끼니와 수락 Menu
- Disabled: 수락/공유 처리 중

## Interaction

- Tap/Keyboard: 끼니 선택, 수락, 재선택, 공유
- Hover/Focus: Card와 Action
- Scroll: 추천 상세와 주의사항
- Transition: 재선택 시 Chat으로 이동, 공유 결과 Dialog

## Navigation

- W-ROUTINE-001 Meal Guide Card에서 진입
- 재선택 → W-CHAT-001
- 수락/Back → W-ROUTINE-001 또는 실행 기록 흐름

## Responsive

- Mobile: 이미지·정보·Action Stack
- Tablet/Desktop: 최대 720px, 이미지와 보조정보만 조건부 분할

## Accessibility

- Focus: 끼니 → 추천 내용 → Action → 주의사항
- Keyboard: 모든 선택과 Action
- Semantics: 추천임을 표시하고 음식 이미지 대체 Text 제공

## Definition of Done

- 추천·빈 상태·오류·수락·공유 상태가 Mock으로 동작한다.
- 추천 이유가 시각적으로 분리되고 의료적 단정 표현이 없다.
- Category Color를 CTA Background로 사용하지 않는다.

# W-HOUSE-001 — 가사 가이드

## 대표 요구사항 ID

`W-HOUSE-001`

## Screen Name

가사 가이드 및 가족 분담

## Purpose

오늘의 가사를 직접 수행, 가전 추천, 가족 분담으로 구분하고 배우자 요청을 생성한다.

## User Goal

몸에 무리가 적은 일만 선택하고 부담되는 일을 배우자에게 요청한다.

## Layout

```text
Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ ConditionSummaryBanner
│  ├─ HouseholdTaskGroup(direct)
│  ├─ HouseholdTaskGroup(appliance recommendation)
│  ├─ HouseholdTaskGroup(family)
│  ├─ HouseholdShareSelector
│  └─ RequestStatusView
└─ PartnerShareResultDialog
```

## Components

`HouseholdTaskGroup`, `GuideTaskCard`, `HouseholdShareSelector`, `RequestStatusView`, `PartnerShareResultDialog`, `StatusBadge`

## Data

- Mock 3개 Group의 Task와 이유·부담 정보
- Mock 배우자 연결 여부, 선택 항목, 요청됨/확인됨/완료 상태
- 가전 항목은 추천으로만 표현하고 실제 실행 성공을 만들지 않는다.

## UI State

- Loading: Guide/요청 상태 조회
- Empty: 추천 Task 없음 또는 연결된 배우자 없음
- Error: 요청 전송/상태 갱신 실패
- Selected: 공유할 Task
- Disabled: 미연결 또는 전송 중

## Interaction

- Tap/Keyboard: Task 선택, 배우자 요청
- Hover/Focus: 선택 Card와 Action
- Scroll: 세 Group과 요청 상태
- Transition: 공유 결과 Dialog, 상태 변경 Live 안내

## Navigation

- W-ROUTINE-001 Household Card에서 진입
- 공유 후 현재 화면 유지, 파트너 상태 반영
- 미연결 상태의 초대 Action이 요구될 경우 W-INVITE-001로 연결하되 문구/노출은 STEP 5 이후 확인

## Responsive

- Mobile: Group과 Task Single Column
- Tablet/Desktop: 최대 720px, 짧은 보조 Task만 2열

## Accessibility

- Focus: Group 순서 → Task → 공유 Action
- Keyboard: 복수 선택과 제출
- Semantics: 담당 주체와 요청 상태를 Text로 읽음

## Definition of Done

- 직접/가전 추천/가족 분담이 명확히 구분된다.
- 요청 상태 3단계가 Wife 화면에 Mock으로 반영된다.
- 실제 ThinQ 제어 API를 호출하거나 계약하지 않는다.

# W-MOTION-001 — 실시간 모션

## 대표 요구사항 ID

`W-MOTION-001`

## Screen Name

홈카메라 실시간 활동/위험 행동 로그

## Purpose

Phase 2에서 Sensor 상태와 당일 위험 행동 Log를 아내·파트너가 공유 조회한다.

## User Goal

카메라 연동 상태와 주의가 필요한 최근 행동을 이해한다.

## Layout

```text
AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ MovementStatusPanel
│  ├─ Medical non-diagnosis banner
│  ├─ Latest important alert
│  └─ RealtimeAlertCard list
└─ AppBottomNavigation
```

기존 `MovementScreen`의 Camera Preview와 제품 Log 화면의 통합 여부는 확정되지 않았으므로 별도 영역으로 유지한다.

## Components

기존 `MovementScreen`, `MovementOverlayPainter`; 향후 `MovementStatusPanel`, `RealtimeAlertCard`, `AppBanner`, `LoadingState`, `EmptyState`, `ErrorState`

## Data

- Phase 2 Mock Sensor 상태와 당일 Log
- 기존 Demo는 실제 WebSocket 데이터이며 MVP Mock UI 범위와 혼합하지 않는다.

## UI State

- Loading: 연결 중/보정 중
- Empty: 정상 연결이나 당일 Log 없음
- Error: 권한 거부, 연결 실패, 데이터 없음
- Selected: Bottom Navigation Realtime
- Disabled: 카메라 동의 철회 또는 Phase 2 비활성

## Interaction

- Tap/Keyboard: Sensor Toggle, Log Detail
- Scroll: 최근 Event
- Transition: 연결 상태 변화
- App/Tab 이탈: Camera와 WebSocket 즉시 정리

## Navigation

- 아내·파트너 Realtime Tab 후보
- MVP 노출 정책 미정이므로 기본 Route에 포함하지 않는다.

## Responsive

- Mobile: Status → Latest → List
- Tablet/Desktop: 최대 720px, Camera 사용 시 비율 유지

## Accessibility

- Focus/Keyboard: Toggle과 Event 순서
- Semantics: 위험도를 색·형태·Text로 함께 전달, 의료 진단 아님 고지

## Definition of Done

- **Phase 2 보류:** MVP 완료 기준에 포함하지 않는다.
- 제품화 시 권한·동의 철회·Resource 정리·당일 Log 초기화가 검증되어야 한다.
- 기존 Demo 회귀 테스트와 실제 Browser 수동 검증이 유지되어야 한다.

# W-HEALTH-001 — 건강 가이드

## 대표 요구사항 ID

`W-HEALTH-001`

## Screen Name

건강 가이드

## Purpose

MVP에서는 오늘 컨디션 기반으로 부담 부위와 스트레칭·산책 등 행동 Guide를 제공한다.

## User Goal

오늘 몸 상태에 맞는 안전한 저부담 활동을 확인하고 완료한다.

## Layout

```text
Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ ConditionSummaryBanner
│  ├─ BodyLoadSummary
│  ├─ SectionHeader
│  ├─ Featured HealthActivityCard
│  ├─ Compact HealthActivityCard list
│  └─ Completion action/status
```

## Components

`ConditionSummaryBanner`, `BodyLoadSummary`, `HealthActivityCard`, `AppProgressMetric`, `GuideTaskCard`, `AppBanner`

## Data

- Mock 컨디션 기반 부위 부담과 집중 부위
- Mock 활동 Title, 시간, 자세 안내, 완료 상태
- 모션 기반 우선순위는 Phase 2까지 사용하지 않는다.

## UI State

- Loading: Guide Skeleton
- Empty: 제공 가능한 활동 없음
- Error: 조회/완료 저장 실패
- Selected: 선택 콘텐츠
- Disabled: 완료 처리 중

## Interaction

- Tap/Keyboard: 영상/자세 보기, 완료 체크, 다른 부위 보기
- Hover/Focus: Actionable Card
- Scroll: 활동 목록

## Navigation

- W-ROUTINE-001 Health Card에서 진입
- 완료/Back → W-ROUTINE-001, 결과는 W-REPORT-001에 반영

## Responsive

- Mobile: Single Column
- Tablet/Desktop: 최대 720px, 짧은 Metric만 조건부 2열

## Accessibility

- Focus: Summary → 활동 → 완료
- Keyboard: Card와 완료 Action
- Semantics: 추천/참고임을 명시, 영상 Thumbnail 대체 Text

## Definition of Done

- 컨디션 기반 Mock Guide와 완료 기록이 동작한다.
- 의료 진단처럼 표현하지 않고 불필요한 불안을 유발하지 않는다.
- 이미지 Asset이 없을 때 무작위 Style Placeholder를 추가하지 않는다.

# W-SLEEP-001 — 수면 가이드

## 대표 요구사항 ID

`W-SLEEP-001`

## Screen Name

수면 가이드

## Purpose

당일 피로·통증에 따른 수면 Tip과 환경 추천값을 선택·조정하고 수행 기록을 남긴다.

## User Goal

오늘 필요한 수면 환경을 선택하고 부담 없이 준비를 마친다.

## Layout

```text
Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ ConditionSummaryBanner / bedtime summary
│  ├─ SleepEnvironmentSelector
│  │  └─ environment cards × 5
│  ├─ edit values action
│  ├─ SleepTipList
│  └─ Primary start/complete action
```

## Components

`ConditionSummaryBanner`, `SleepEnvironmentSelector`, `AppSelectionCard`, `SleepTipList`, `AppButton`, `AppBanner`

## Data

- Mock 권장 취침시간, 환경 5개 항목, 선택 여부, 추천/수정값, Tip
- 실제 가전 상태나 실행 결과를 만들지 않는다.

## UI State

- Loading: 추천 조회
- Empty: 환경 추천 없음
- Error: 조회/설정 저장 실패
- Selected: 실행할 환경 항목
- Disabled: 선택 없음 또는 저장 중

## Interaction

- Tap/Keyboard: 복수 선택, 값 수정, 시작/완료
- Hover/Focus: 환경 Card와 Action
- Scroll: 환경과 Tip
- Transition: 설정 편집 영역 또는 Modal

## Navigation

- W-ROUTINE-001 Sleep Card에서 진입
- 수행 기록 성공/Back → W-ROUTINE-001, 결과는 W-REPORT-001에 반영

## Responsive

- Mobile: 가용 폭에 따라 1~2열, 200% Text는 1열
- Tablet/Desktop: 최대 720px, 환경 Card 2열

## Accessibility

- Focus: 환경 항목 → 수정 → Tip → Primary Action
- Keyboard: Card 선택과 값 조정
- Semantics: 선택됨, 추천값/수정값, 실제 가전 실행이 아님을 필요한 위치에서 안내

## Definition of Done

- 추천값·수정값·선택·저장 오류가 Mock으로 재현된다.
- MVP에서는 실제 가전 실행을 호출하지 않는다.
- 완료 결과가 Routine/Report Mock 데이터에 반영된다.

# W-CHAT-001 — 식사 재조정 채팅

## 대표 요구사항 ID

`W-CHAT-001`

## Screen Name

AI 챗봇 — 식사 가이드 재조정

## Purpose

사용자의 현재 불편과 요청을 반영해 식사 추천을 대화로 재선택한다.

## User Goal

원하지 않는 추천의 이유를 말하고 더 적합한 Menu를 선택한다.

## Layout

```text
AppShell/Page
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ ConditionSummaryBanner
│  ├─ MealChatConversation
│  │  ├─ assistant/user bubbles
│  │  ├─ quick replies
│  │  └─ MealRechoiceCard
│  └─ composer / send action
└─ AppBottomNavigation when tab context
```

## Components

`ConditionSummaryBanner`, `MealChatConversation`, `MealRechoiceCard`, `AppTextField`, `AppButton`, `ErrorState`

## Data

- Mock 식사 대화 Message와 응답 Delay
- Mock 재추천 후보와 적용 상태
- 식사 외 전체 Routine 조정 응답은 Phase 2로 제외

## UI State

- Default: 초기 안내 또는 대화 내역
- Loading: AI 응답 대기
- Empty: 대화 시작 전 안내
- Error: 응답 실패와 재시도
- Selected: 적용할 새 추천
- Disabled: 빈 입력/응답 중 전송

## Interaction

- Input: Message 작성과 제출
- Tap/Keyboard: Quick Reply, 재추천 적용, 다른 Menu 보기
- Scroll: 새 Message 도착 시 접근성을 해치지 않는 범위에서 이동
- Transition: 적용 성공 후 Meal Guide 갱신

## Navigation

- Bottom Chat Tab 또는 W-MEAL-001 재선택에서 진입
- 추천 적용 → 갱신된 W-MEAL-001
- Back → 이전 Meal/Home Context

## Responsive

- Mobile: Bubble 78/84%, Composer Safe Area 고정
- Tablet/Desktop: 최대 720px, Bubble 최대 폭 유지

## Accessibility

- Focus: Message 목록 읽기 → Quick Reply → Composer → Send
- Keyboard: Enter 정책과 줄바꿈 정책 구분
- Semantics: 새 응답 Live Region, AI 추천임을 Label로 표시

## Definition of Done

- 대화 시작·응답 대기·실패·재추천·적용 Loop가 Mock으로 동작한다.
- 식사 외 요청을 실제 지원하는 것처럼 구현하지 않는다.
- Bubble 색 대비와 Keyboard Composer가 검증된다.

# W-REPORT-001 — Daily 리포트

## 대표 요구사항 ID

`W-REPORT-001`

## Screen Name

오늘의 기록 / Daily 리포트

## Purpose

당일 컨디션, 수행 Routine과 가족 분담 결과를 요약하고 Calendar 기록으로 확정한다.

## User Goal

오늘 수행한 내용을 검토하고 저장·공유한다.

## Layout

```text
Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ DailyReportSummary
│  ├─ RoutineRecordList
│  ├─ FamilyParticipationSummary
│  ├─ save/finish + share actions
│  └─ report notice
└─ PartnerShareResultDialog
```

## Components

`DailyReportSummary`, `MetricCard`, `RoutineRecordList`, `FamilyParticipationSummary`, `AppButton`, `PartnerShareResultDialog`

## Data

- Mock 날짜, 주차, 완료/건너뜀 Routine, 가족 요청 상태
- MVP 리포트에는 실제 가전 이력과 모션 요약을 포함하지 않는다.

## UI State

- Loading: 리포트 생성/조회
- Empty: 완료 기록 없음
- Error: 생성·저장·공유 실패
- Disabled: 저장/공유 처리 중

## Interaction

- Tap/Keyboard: 기록 Detail, 저장하고 마치기, 공유
- Scroll: 기록과 가족 요약
- Transition: 공유 결과 Dialog, 저장 후 Calendar

## Navigation

- W-ROUTINE-001의 하루 마치기 또는 W-CAL-001 날짜 선택에서 진입
- 저장 완료 → W-CAL-001
- Back → 원래 Home/Calendar Context

## Responsive

- Mobile: Metric Stack, Action Stack
- Tablet/Desktop: Metric 2~3열 조건부, 전체 최대 720px

## Accessibility

- Focus: Summary → 기록 → 가족 요약 → Action
- Keyboard: 기록과 Dialog 탐색
- Semantics: 완료/건너뜀/파트너 완료를 색 없이 읽음

## Definition of Done

- 생성·빈 상태·오류·저장·공유 상태가 구현된다.
- MVP 제외 데이터가 리포트에 노출되지 않는다.
- 저장 후 Calendar Mock 데이터에서 날짜 기록을 확인할 수 있다.

# W-CAL-001 — 컨디션 캘린더

## 대표 요구사항 ID

`W-CAL-001`

## Screen Name

컨디션 캘린더

## Purpose

날짜별 컨디션과 Routine 수행 기록을 탐색한다.

## User Goal

월별 변화와 선택 날짜의 핵심 기록을 빠르게 확인한다.

## Layout

```text
AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ Month navigation
│  ├─ ConditionCalendar
│  │  ├─ weekday header
│  │  ├─ date grid
│  │  └─ always-visible legend
│  ├─ selected date summary
│  └─ report detail action
└─ AppBottomNavigation
```

## Components

`AppShell`, `AppTopBar`, `ConditionCalendar`, `ConditionSummaryBanner`, `MetricCard`, `AppButton`, `EmptyState`, `ErrorState`

## Data

- Mock 월별 Date 상태, 컨디션 수준, 기록 존재 여부
- Mock 선택 날짜 Summary와 Report Reference

## UI State

- Loading: 월 데이터 Skeleton
- Empty: 월 기록 없음 또는 선택일 기록 없음
- Error: 월/상세 조회 실패
- Selected: 선택 날짜와 Bottom Navigation Calendar
- Disabled: 미래 날짜 또는 조회 불가 날짜

## Interaction

- Tap/Keyboard: 이전/다음 월, 날짜 Grid, Report Detail
- Hover/Focus: 날짜 Cell
- Transition: 월/선택일 Summary 변경

## Navigation

- Bottom Calendar Tab 또는 W-REPORT-001 저장 후 진입
- 선택일 상세 → W-REPORT-001
- 다른 Tab → 해당 Shell Route

## Responsive

- Mobile: Calendar 위, Summary 아래
- Tablet/Desktop: 최대 720px; 충분한 폭에서 Calendar와 Secondary Summary만 조건부 분리

## Accessibility

- Focus: 월 이동 → 날짜 Grid → Legend → Summary
- Keyboard: Arrow Key Grid 이동, Enter 선택
- Semantics: 날짜, 컨디션 Text 상태, 선택/기록 여부를 함께 읽음

## Definition of Done

- 월 이동, 날짜 선택, 빈 상태, 오류, Detail 이동이 동작한다.
- 다수의 진한 원형 Fill 대신 Dot/Ring/Tint와 항상 보이는 Legend를 사용한다.
- 최소 44×44 날짜 Target과 200% Text를 검증한다.

# W-SETTING-001 — 설정

## 대표 요구사항 ID

`W-SETTING-001`

## Screen Name

설정

## Purpose

Phase 2 설정 기능의 전역 진입점이다.

## User Goal

향후 제공될 설정 범위를 확인한다.

## Layout

```text
Page
├─ AppTopBar
└─ ResponsivePageContent(form)
   └─ Phase 2 information state
```

## Components

`AppTopBar`, `ResponsivePageContent`, `EmptyState` 또는 `AppBanner`

## Data

- 구체적인 설정 항목은 문서에 없으므로 Mock Setting을 만들지 않는다.

## UI State

- Default: Phase 2 안내
- Disabled: 정의되지 않은 설정 Action은 노출하지 않음

## Interaction

- Tap/Keyboard: Back만 제공

## Navigation

- Wife Profile Menu에서 진입 후보
- Back → 이전 화면

## Responsive

- 모든 폭에서 Form 최대 560px

## Accessibility

- Focus/Keyboard: Back과 안내 순서
- Semantics: 준비 중 상태를 명확한 Text로 제공

## Definition of Done

- **Phase 2 보류:** 상세 요구사항 확정 전 제품 기능처럼 구현하지 않는다.
- 임의 Setting Toggle이나 Backend Contract를 추가하지 않는다.

# H-REPORT-001 — 파트너 아침 리포트

## 대표 요구사항 ID

`H-REPORT-001`

## Screen Name

오전 컨디션 리포트

## Purpose

파트너가 임산부의 임신 주차, 당일 컨디션, 예정 활동과 4개 Guide 요약을 확인한다.

## User Goal

오늘 필요한 지원을 빠르게 이해한다.

## Layout

```text
Partner AppShell
├─ AppTopBar(profile/notification)
├─ ResponsivePageContent(dashboard)
│  ├─ PartnerMorningSummary
│  ├─ ConditionSummaryBanner
│  ├─ Guide summary list
│  └─ Household request entry
└─ Partner navigation                  # 구성 확정 전 주입형
```

## Components

`AppShell`, `AppTopBar`, `PartnerMorningSummary`, `ConditionSummaryBanner`, `RoutineGuideCard` read-only 또는 `GuideTaskCard`, `StatusBadge`

## Data

- Mock 공유 허용 범위 내 임신 주차·컨디션·활동·Guide Summary
- Mock 미연결/공유 데이터 없음 상태

## UI State

- Loading: 리포트 조회
- Empty: 오늘 리포트 없음 또는 공유 데이터 없음
- Error: 조회 실패/연결 해제
- Disabled: 공유 동의가 없는 Detail

## Interaction

- Tap/Keyboard: 가사 요청, Calendar, Notification
- Hover/Focus: Actionable Summary
- Scroll: 전체 리포트

## Navigation

- Notification 또는 오늘 날짜 Calendar에서 진입
- 가사 요청 → H-REQUEST-001
- Calendar → H-CAL-001

## Responsive

- Mobile: Single Column
- Tablet/Desktop: 최대 720px, 보조 Summary만 2열

## Accessibility

- Focus: 상태 Summary → Guide → 요청 Action
- Keyboard: 모든 Detail Link
- Semantics: 공유된 정보임과 상태를 Text로 전달

## Definition of Done

- 리포트 있음/없음/연결 오류가 Mock으로 재현된다.
- 허용되지 않은 민감정보가 노출되지 않는다.
- 파트너가 상태를 변경할 수 없는 읽기 전용 영역이 명확하다.

# H-CAL-001 — 파트너 캘린더

## 대표 요구사항 ID

`H-CAL-001`

## Screen Name

파트너 캘린더 / 메인

## Purpose

연결 완료 후 파트너의 Main으로 날짜별 임산부 생활 기록을 조회한다.

## User Goal

오늘과 과거의 공유된 생활 기록을 날짜별로 확인한다.

## Layout

```text
Partner AppShell
├─ AppTopBar(profile/notification)
├─ ResponsivePageContent(dashboard)
│  ├─ Month navigation
│  ├─ ConditionCalendar(partner read-only)
│  ├─ selected date summary
│  └─ report/request entries
└─ Partner navigation                  # 미정
```

## Components

`AppShell`, `AppTopBar`, `ConditionCalendar`, `PartnerMorningSummary`, `RoutineRecordList`, `EmptyState`, `ErrorState`

## Data

- Mock 공유 가능한 월 기록과 선택일 Summary
- Wife Calendar와 같은 날짜 Record Projection을 읽기 전용으로 사용

## UI State

- Loading: 월 기록 조회
- Empty: 기록 없는 달/날짜
- Error: 연결 또는 조회 실패
- Selected: 날짜
- Disabled: 공유되지 않은 날짜/항목

## Interaction

- Tap/Keyboard: 월 이동, 날짜 선택, 리포트/요청 Detail
- Hover/Focus: Calendar Cell
- Transition: 선택일 Summary 갱신

## Navigation

- 초대 연결 완료 후 Partner Main
- 리포트 → H-REPORT-001
- 요청 → H-REQUEST-001
- 알림 → H-NOTI-001, Profile → H-PROFILE-001

## Responsive

- Mobile: Calendar → Summary Stack
- Tablet/Desktop: 최대 720px, Secondary Summary 조건부 2열

## Accessibility

- Focus/Keyboard: Calendar Grid 규칙을 W-CAL-001와 공유
- Semantics: 공유 여부, 날짜, 컨디션과 기록 존재 여부

## Definition of Done

- Partner Main, 월 이동, 날짜 선택, 읽기 전용 상세가 동작한다.
- Wife Calendar Component를 Variant로 재사용한다.
- Partner Bottom Navigation은 문서에 명시된 Calendar/Realtime만 사용하고 추가 항목을 임의로 고정하지 않는다.

# H-NOTI-001 — 알림

## 대표 요구사항 ID

`H-NOTI-001`

## Screen Name

파트너 앱 내 알림 목록

## Purpose

오전 리포트, 가사 요청, 미확인·미완료 상태를 한 목록에서 제공한다.

## User Goal

새로운 지원 요청을 놓치지 않고 관련 화면으로 이동한다.

## Layout

```text
Partner Page/AppShell
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ SectionHeader / unread count
│  └─ NotificationList
│     └─ NotificationListItem × n
└─ Partner navigation if defined
```

## Components

`AppTopBar`, `SectionHeader`, `NotificationListItem`, `StatusBadge`, `LoadingState`, `EmptyState`, `ErrorState`

## Data

- Mock 리포트·요청·Reminder 알림, 읽음 여부, 시각, 목적 Screen Reference
- 실제 Push 수신은 Phase 2이며 포함하지 않는다.

## UI State

- Loading: 목록 Skeleton
- Empty: 알림 없음
- Error: 조회/읽음 처리 실패
- Selected: Focus/선택 알림
- Disabled: 더 이상 접근할 수 없는 알림

## Interaction

- Tap/Keyboard: 알림 선택 및 읽음 처리
- Hover/Focus: 목록 Item
- Scroll: 긴 목록

## Navigation

- AppBar 알림 Bell에서 진입
- 리포트 알림 → H-REPORT-001
- 가사 요청 → H-REQUEST-001
- Back → 이전 Partner 화면

## Responsive

- 모든 폭에서 최대 720px Single List

## Accessibility

- Focus: 최신 알림부터 DOM 순서
- Keyboard: Item 활성화
- Semantics: 읽음/읽지 않음, 알림 유형, 발생 시각

## Definition of Done

- Loading/Empty/Error/읽음 상태와 목적 화면 이동이 Mock으로 동작한다.
- Push Infra를 구현하지 않는다.
- 읽지 않음 상태를 색만으로 표시하지 않는다.

# H-REQUEST-001 — 가사 요청

## 대표 요구사항 ID

`H-REQUEST-001`

## Screen Name

파트너 가사 요청 카드

## Purpose

임산부가 보낸 요청을 확인하고 요청됨 → 확인됨 → 완료 상태로 처리한다.

## User Goal

요청 이유와 할 일을 이해하고 처리 상태를 공유한다.

## Layout

```text
Partner Page
├─ AppTopBar
├─ ResponsivePageContent(dashboard)
│  ├─ request context banner
│  ├─ PartnerRequestCard
│  ├─ RequestStatusView / timeline
│  └─ current allowed action
└─ success feedback
```

## Components

`PartnerRequestCard`, `RequestStatusView`, `StatusBadge`, `AppButton`, `AppBanner`, `ErrorState`

## Data

- Mock 요청 이유, Task, 보조 정보, 요청자, 시각, 상태
- 공유 `MockAppStore`를 통해 Wife 가사 화면과 Report에 반영

## UI State

- Loading: 요청 조회
- Empty: 요청 삭제/접근 불가
- Error: 확인/완료 처리 실패
- Disabled: 이미 완료되었거나 처리 중인 Action

## Interaction

- Tap/Keyboard: 확인, 완료했어요, 재시도
- Hover/Focus: 허용 Action
- Transition: 상태 Badge와 성공 안내

## Navigation

- H-NOTI-001 알림 또는 H-REPORT-001·H-CAL-001 Summary에서 진입
- 완료 후 이전 화면 또는 요청 Detail 유지

## Responsive

- Mobile: Single Column, Action Full Width
- Tablet/Desktop: 최대 720px, Card Content 가변 높이

## Accessibility

- Focus: Context → 요청 → 현재 Action
- Keyboard: 상태 전환 Action
- Semantics: 현재 상태와 마지막 갱신을 Live 안내

## Definition of Done

- 3단계 상태 전환과 오류 재시도가 Mock으로 동작한다.
- 완료가 Wife Routine/Report 재조회에 반영된다.
- 허용되지 않은 상태 전환 Action은 노출하지 않는다.

# H-PROFILE-001 — 파트너 프로필

## 대표 요구사항 ID

`H-PROFILE-001`

## Screen Name

파트너 프로필 조회

## Purpose

파트너가 자신의 기본 Profile과 연결 상태를 읽기 전용으로 확인한다.

## User Goal

현재 계정과 연결 관계를 확인한다.

## Layout

```text
Page
├─ AppTopBar
└─ ResponsivePageContent(form)
   ├─ profile summary
   └─ connection status
```

## Components

`AppTopBar`, `ResponsivePageContent`, `ProfileSummary(readOnlyPartner)`, `StatusBadge`, `LoadingState`, `ErrorState`

## Data

- Mock 파트너 기본 Profile과 연결 상태
- 문서에 정의되지 않은 수정 Field는 추가하지 않는다.

## UI State

- Loading: Profile 조회
- Empty: 연결/정보 없음
- Error: 조회 실패
- Disabled: 모든 Profile Field 읽기 전용

## Interaction

- Tap/Keyboard: Back만, 정의된 추가 Action 없음

## Navigation

- 모든 Partner 화면의 우측 상단 Profile Button에서 직접 진입
- Back → 이전 화면

## Responsive

- 모든 폭에서 최대 560px

## Accessibility

- Focus: Back과 읽기 순서
- Semantics: 읽기 전용과 연결 상태 명시

## Definition of Done

- 조회/빈 상태/오류가 구현된다.
- Profile 수정 UI를 제공하지 않는다.
- Profile Menu 단계를 거치지 않고 직접 진입한다.

# H-INVITE-001 — 초대 수락

## 대표 요구사항 ID

`H-INVITE-001`

## Screen Name

배우자 초대 수락 및 계정 연결

## Purpose

외부 초대 Context를 검증하고 파트너 연결 결과를 안내한다.

## User Goal

유효한 초대를 수락하고 Partner Main으로 이동하거나 실패 이유를 이해한다.

## Layout

```text
Standalone Page
├─ AppTopBar(optional back)
└─ ResponsivePageContent(compact)
   └─ InvitationAcceptancePanel
      ├─ inviter / benefit context
      ├─ validation status
      ├─ accept/retry action
      └─ result guidance
```

## Components

`InvitationAcceptancePanel`, `AppBanner`, `AppButton`, `LoadingState`, `ErrorState`

## Data

- Mock 초대 상태: 검증 중, 유효, 로그인 필요, 만료, 이미 사용됨, 중복 연결, 연결 중, 완료
- 실제 Token, 인증 또는 App Store 연결은 구현하지 않는다.

## UI State

- Loading: Link 검증/연결
- Error: 만료·재사용·중복·연결 실패
- Disabled: 처리 중 수락 Action

## Interaction

- Tap/Keyboard: 수락, 재시도, 계속
- Transition: 검증 → 수락 → 완료

## Navigation

- 외부 Invite Entry Adapter에서 진입
- 완료 → H-CAL-001
- 로그인/설치 필요 상태는 실제 화면 미정이므로 안내 상태까지만 Mock

## Responsive

- 모든 폭에서 최대 480px, Mobile 20px Padding

## Accessibility

- Focus: 상태 안내 → Primary Action
- Keyboard: Action과 오류 재시도
- Semantics: 만료/중복/성공 상태 Live 안내

## Definition of Done

- 모든 Link 상태가 Mock Scenario로 재현된다.
- 외부 URL·인증 Contract를 임의 확정하지 않는다.
- 성공 후 Partner Main 이동이 Route Test로 검증된다.

# 구현 Task 순서

## 공통 선행 조건

- STEP 3의 Design Token과 Theme
- STEP 4의 Foundation 및 필요한 Shared Component
- 현재 Flutter 기본 Navigator 기반 Skeleton Router 계약을 유지한다. `provider`, `go_router` 추가 도입은 별도 승인 후 진행한다.
- 각 Task는 관련 Mock Model/Service/Controller와 화면 Widget Test만 포함하며 Backend를 구현하지 않음

## UI-001

- **Goal:** 단계형 Profile 등록·수정 기반 완성
- **Related Screen:** W-PROFILE-001
- **Components:** ProfileWizardForm, ProfileSummary, Form 계열 Foundation
- **Files:** `features/profile/{models,services,state,pages,widgets}`, Profile Mock Fixture
- **Dependencies:** AppTheme, AppButton, AppTextField, AppSelectionCard, ResponsivePageContent, AppTopBar
- **Validation:** 단계·Validation·저장 실패 Widget Test, 200% Text, Keyboard
- **Definition of Done:** 최초/수정 분기와 Mock 저장이 완료되고 다른 Feature에 직접 의존하지 않음

## UI-002

- **Goal:** 임산부 초대 발급·공유·나중에 흐름 구현
- **Related Screen:** W-INVITE-001
- **Components:** PartnerInvitePanel, PartnerShareResultDialog
- **Files:** `features/invitation/{models,services,state,pages,widgets}`
- **Dependencies:** UI-001 완료 Navigation, AppDialog, AppBanner
- **Validation:** 생성/공유/실패/나중에 Scenario Test
- **Definition of Done:** 실제 외부 계약 없이 Mock 초대 흐름과 Home 이동 완료

## UI-003

- **Goal:** 초대 수락 상태와 Partner 연결 완료 구현
- **Related Screen:** H-INVITE-001
- **Components:** InvitationAcceptancePanel
- **Files:** Invitation Feature의 Acceptance Page/State/Mock Scenario
- **Dependencies:** UI-002의 공통 Invitation Model/Service Contract
- **Validation:** 유효·만료·재사용·중복·성공 Route/Widget Test
- **Definition of Done:** 인증을 구현하지 않고 모든 문서상 Link 상태와 Main 이동을 표현

## UI-004

- **Goal:** 오늘 컨디션 입력·수정 구현
- **Related Screen:** W-COND-001
- **Components:** ConditionSelector, BodyPainSelector, AppProgressMetric
- **Files:** `features/condition/{models,services,state,pages,widgets}`
- **Dependencies:** UI-001 Profile/주차 Mock, Form Foundation
- **Validation:** 60초 핵심 흐름, 단계 Keyboard 조작, Validation Test
- **Definition of Done:** 입력/수정/오류/저장 결과가 Mock Service에 반영

## UI-005

- **Goal:** 예정 활동 선택과 Routine 생성 요청 연결
- **Related Screen:** W-ACT-001
- **Components:** PlannedActivitySelector
- **Files:** Condition Feature의 Activity Page/State/Fixture
- **Dependencies:** UI-004, AppSelectionCard
- **Validation:** 복수 선택, Disabled, 제출 오류 Widget Test
- **Definition of Done:** 선택값 저장 후 Home 생성 상태로 전환

## UI-006

- **Goal:** 조건 분기와 4개 Guide를 가진 통합 Home 구현
- **Related Screen:** W-ROUTINE-001
- **Components:** AppShell, PregnancyWeekHero, RoutineGenerationState, DailyCareSection, RoutineGuideCard
- **Files:** `features/routine/{models,services,state,pages,widgets}`, Shell/Router Files
- **Dependencies:** UI-001, UI-004, UI-005, AppShell/Navigation
- **Validation:** 미입력·생성·성공·Fallback·저장 Routine Golden/Widget/Route Test
- **Definition of Done:** 컨디션 미입력 시 Guide 미노출, 상태별 Navigation과 Mock Routine 표시

## UI-007

- **Goal:** 끼니 선택과 추천 상세·수락·공유 구현
- **Related Screen:** W-MEAL-001
- **Components:** MealPeriodSelector, MealRecommendationCard, MealCautionSection
- **Files:** `features/meal/{models,services,state,pages,widgets}`
- **Dependencies:** UI-006 Routine Summary, Category/Share Shared Component
- **Validation:** 추천/Empty/Error/수락/공유 Widget Test
- **Definition of Done:** Meal 상태가 Routine과 Mock Store에 반영

## UI-008

- **Goal:** 식사 재추천 대화 Loop 구현
- **Related Screen:** W-CHAT-001
- **Components:** MealChatConversation, MealRechoiceCard
- **Files:** Meal Feature Chat Page/State/Mock Conversation
- **Dependencies:** UI-007
- **Validation:** 응답 지연·실패·반복 재추천·적용 Test, Keyboard Composer
- **Definition of Done:** 식사 범위만 조정하고 적용 후 Meal 화면 갱신

## UI-009

- **Goal:** 컨디션 기반 건강 Guide와 완료 기록 구현
- **Related Screen:** W-HEALTH-001
- **Components:** BodyLoadSummary, HealthActivityCard
- **Files:** `features/health/{models,services,state,pages,widgets}`
- **Dependencies:** UI-004, UI-006, GuideTaskCard
- **Validation:** Guide/Empty/Error/완료 Test, 의료 표현 점검
- **Definition of Done:** 모션 없이 컨디션 기반 Mock Guide와 기록 반영

## UI-010

- **Goal:** 수면 환경 선택·수정·완료 기록 구현
- **Related Screen:** W-SLEEP-001
- **Components:** SleepEnvironmentSelector, SleepTipList
- **Files:** `features/sleep/{models,services,state,pages,widgets}`
- **Dependencies:** UI-004, UI-006, AppSelectionCard
- **Validation:** 5개 환경 선택·값 변경·오류·200% Text Test
- **Definition of Done:** 실제 가전 실행 없이 추천과 수행 기록만 반영

## UI-011

- **Goal:** 가사 3개 Group과 파트너 요청 생성 구현
- **Related Screen:** W-HOUSE-001
- **Components:** HouseholdTaskGroup, HouseholdShareSelector, RequestStatusView
- **Files:** `features/household/{models,services,state,pages,widgets}`
- **Dependencies:** UI-002 연결 상태, UI-006, 공유 MockAppStore
- **Validation:** 미연결·선택·전송·3단계 상태 표시 Test
- **Definition of Done:** 가전은 추천에 머물고 파트너 요청은 Mock Store에 생성

## UI-012

- **Goal:** 파트너 가사 요청 확인·완료 구현
- **Related Screen:** H-REQUEST-001
- **Components:** PartnerRequestCard, RequestStatusView
- **Files:** Household Partner Page/State
- **Dependencies:** UI-011
- **Validation:** 요청됨→확인됨→완료 Contract/Widget Test
- **Definition of Done:** 상태가 Wife 화면과 Report용 Mock Store에 일관되게 반영

## UI-013

- **Goal:** 파트너 읽기 전용 Profile 구현
- **Related Screen:** H-PROFILE-001
- **Components:** ProfileSummary(readOnlyPartner)
- **Files:** Profile Partner Page/State
- **Dependencies:** UI-001 공통 Profile Model, UI-003 연결 상태
- **Validation:** Loading/Empty/Error와 수정 Action 부재 Test
- **Definition of Done:** 전역 Button에서 직접 진입하고 읽기 전용 Semantics 제공

## UI-014

- **Goal:** 앱 내 파트너 알림 목록 구현
- **Related Screen:** H-NOTI-001
- **Components:** NotificationListItem, 상태 Shared Components
- **Files:** `features/notification/{models,services,state,pages,widgets}`
- **Dependencies:** UI-003, UI-012, Report Route Placeholder
- **Validation:** Loading/Empty/Error/읽음/목적 Route Test
- **Definition of Done:** Push 없이 Mock Inbox와 요청/리포트 이동 제공

## UI-015

- **Goal:** Wife Daily Report와 저장·공유 구현
- **Related Screen:** W-REPORT-001
- **Components:** DailyReportSummary, RoutineRecordList, FamilyParticipationSummary
- **Files:** `features/report/{models,services,state,pages,widgets}`
- **Dependencies:** UI-007, UI-009, UI-010, UI-012의 수행 기록
- **Validation:** 집계·Empty/Error·저장/공유 Test
- **Definition of Done:** MVP 데이터만 포함한 Report가 Calendar Store에 저장

## UI-016

- **Goal:** Wife 컨디션 Calendar 구현
- **Related Screen:** W-CAL-001
- **Components:** ConditionCalendar, Selected Date Summary
- **Files:** Report Feature의 Wife Calendar Page/State
- **Dependencies:** UI-015
- **Validation:** 월 이동·Keyboard Grid·빈 날짜·Detail Route Test
- **Definition of Done:** Legend/선택 Ring/44px Cell과 날짜별 Report 연결 완료

## UI-017

- **Goal:** Partner 오전 Report 구현
- **Related Screen:** H-REPORT-001
- **Components:** PartnerMorningSummary, read-only Guide Summary
- **Files:** Report Feature의 Partner Morning Page/State
- **Dependencies:** UI-003, UI-011/12, UI-015 Report Projection
- **Validation:** 공유 범위·Empty/Error·요청 Route Test
- **Definition of Done:** 공유 허용 데이터만 읽기 전용으로 표시

## UI-018

- **Goal:** Partner Main Calendar와 날짜별 기록 구현
- **Related Screen:** H-CAL-001
- **Components:** ConditionCalendar(partner), PartnerMorningSummary
- **Files:** Report Feature의 Partner Calendar Page/State
- **Dependencies:** UI-016, UI-017, UI-014
- **Validation:** Main Redirect·월/날짜 탐색·권한 상태 Test
- **Definition of Done:** 공통 Calendar를 재사용하고 미정 Tab 구성은 주입형으로 유지

## UI-019

- **Status:** Deferred (Phase 2)
- **Goal:** 정의된 범위가 생길 때 설정 화면 구현
- **Related Screen:** W-SETTING-001
- **Components:** AppTopBar, EmptyState/AppBanner
- **Files:** 요구사항 확정 후 결정
- **Dependencies:** Phase 2 설정 요구사항 확정
- **Validation:** 확정 전 없음
- **Definition of Done:** 현재는 Task 보류 상태를 유지하고 임의 Toggle을 만들지 않음

## UI-020

- **Status:** Deferred (Phase 2)
- **Goal:** 기존 모션 Demo와 제품 실시간 Log 화면의 Phase 2 통합
- **Related Screen:** W-MOTION-001
- **Components:** MovementStatusPanel, RealtimeAlertCard, 기존 MovementScreen
- **Files:** 기존 `features/movement/**`를 보존하며 확정 범위만 추가
- **Dependencies:** Phase 2 노출 정책, 개인정보 동의, Platform 전략, 실제 Browser 검증
- **Validation:** 기존 Test, Camera 수동 Test, Tab 이탈 Resource 정리, 접근성
- **Definition of Done:** 현재는 MVP에서 보류하며 기존 Demo를 회귀시키지 않음

# 단계별 실행 Gate

- UI-001~005: 입력 기반을 각각 완료·검토한 뒤 Home으로 진행한다.
- UI-006: Home의 모든 상태가 검증된 뒤 Guide Task를 하나씩 시작한다.
- UI-007~012: 식사 → 채팅 → 건강 → 수면 → 가사 → 파트너 요청 순으로 독립 완료한다.
- UI-013~018: 파트너 조회·알림과 Report/Calendar를 기존 Mock Store 위에 추가한다.
- UI-019~020: Phase 2 요구사항과 미정 정책이 확정되기 전 시작하지 않는다.
- 각 Task 종료 시 `flutter analyze`, 관련 `flutter test`, 주요 Viewport/Keyboard/200% Text 수동 검증을 수행한다.
- 화면별 검토가 끝나기 전 다음 Screen 묶음을 대량 구현하지 않는다.

# 이번 STEP 변경 범위

이번 STEP 5에서는 다음 문서만 생성·갱신한다.

```text
docs/development/05_ui_implementation_plan.md
docs/development/frontend_workflow.md
```

Flutter Page, Component, Mock Service, Package는 생성하거나 수정하지 않는다.

# STEP 6 Skeleton 반영 기록

STEP 5 이후 별도 Skeleton 구현 작업으로 Design Token/Theme 최소 기반, 공통 Navigation Component, 제품 화면 20개와 중앙 Router가 생성되었다. 상세 화면 Task의 `Todo` 상태는 유지하며, 구현자는 새 Route를 만들지 않고 최신 `ROUTE_MAP.md`의 확정된 내부 Path와 Context 계약을 사용한다.

- 프로필·배우자 초대: 최초/수정 및 온보딩/수동 진입 Path 분리
- 동적 Parameter: `date`, `requestId`, `token` 전달
- Wife Shell: Home, Realtime, Chat, Calendar
- Partner Shell: 문서에 명시된 Calendar, Realtime 최소 항목
- 인증·Session Guard, 외부 Deep Link Domain, Feature Mock Service: 후속 구현
