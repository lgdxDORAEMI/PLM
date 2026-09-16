# Component Architecture 원칙

## 분류 기준

| 분류 | 책임 | 허용 의존성 | 배치 |
|---|---|---|---|
| Design System Component | 시각 규칙과 기본 상호작용을 일관되게 제공 | Flutter, Design Token | `lib/design_system/components` |
| Shared Component | 여러 Feature에서 재사용하는 PLM 제품 구조와 도메인 중립 조합 제공 | Design System, `core`, 공통 Model | `lib/widgets` |
| Feature Component | 특정 업무 의미와 Feature Model을 화면에 표현 | Design System, Shared, 동일 Feature의 Model/State | `lib/features/{feature}/widgets` |

Component는 Service를 직접 호출하지 않는다. 값과 상태는 Props로 받고, 사용자 행동은 Callback으로 Page 또는 Controller에 전달한다. Routing과 Dialog 표시 여부도 Component가 임의로 결정하지 않는다.

## Component 승격 기준

```text
한 Page에서만 사용
→ Page 내부 Private Widget

같은 Feature의 2개 이상 Page에서 사용
→ Feature Component

서로 다른 Feature에서 같은 의미와 동작으로 사용
→ Shared Component

업무 의미 없이 시각 규칙과 기본 Control만 제공
→ Design System Component
```

비슷해 보인다는 이유만으로 공통화하지 않는다. Props가 계속 늘어나거나 Feature별 조건 분기가 필요하면 공통 Component가 아니라 각 Feature 내부 조합으로 유지한다.

# 1. Design System Component

Design System Component는 Profile, Meal 같은 업무 용어를 알지 않는다. `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppElevation`, `AppIconSize`만 사용해 기본 시각 언어와 접근성을 보장한다.

## Component 목록

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `AppButton` | 제품 전체 Action 위계와 상태 통일 | 모든 Form, Guide, Modal, Report | primary, secondary, text; normal/compact; optional fullWidth | `label`, `onPressed`, `leadingIcon`, `trailingIcon`, `isLoading`, `isFullWidth`, `semanticLabel` | default, hover, focus, pressed, disabled, loading | Click/Keyboard Activate, Loading 중 중복 실행 차단 | Mobile Primary CTA는 Full Width 가능, 큰 화면은 내용 폭 또는 명시 폭 사용 | Primary 600/700/800, disabled, height 52, radius 14, 15/600, spacing 20 |
| `AppIconButton` | Icon-only Action의 크기·Focus·Tooltip 보장 | AppBar Back/Menu, Calendar 이동, Modal 닫기 | standard, subtle | `icon`, `onPressed`, `tooltip`, `semanticLabel`, `isSelected` | default, hover, focus, pressed, selected, disabled | Click/Keyboard Activate, Tooltip | 보이는 Icon은 20/24, Hit Area는 항상 최소 44×44 | icon 20/24, primary, text tertiary, focus ring, radius 10 |
| `AppTextField` | Label이 있는 Text/Numeric 입력의 일관성 제공 | Profile, Condition 보조 입력, Chat 입력값 외 일반 Form | text, number, multiline, readOnly | `label`, `value/controller`, `hint`, `helperText`, `errorText`, `suffix`, `keyboardType`, `onChanged`, `onSubmitted`, `enabled`, `maxLines` | default, hover, focus, filled, error, disabled | 입력, 제출, Keyboard Focus; Label은 항상 유지 | 기본 높이 52, Multiline은 Content에 따라 증가, 좁은 폭에서 Suffix가 Text를 가리지 않음 | surface, border default/strong, primary500/100, error, radius 12, body1, label |
| `AppCard` | Border 중심의 공통 Surface Container 제공 | 정보 Card, Feature Composite의 외곽 | standard, actionable, subtle | `child`, `padding`, `onTap`, `semanticLabel`, `backgroundRole` | default, hover/actionable, focus/actionable, pressed, disabled | `onTap`이 있을 때만 Pointer/Keyboard와 Hover 제공 | Content 높이에 맞게 늘어나며 고정 높이 금지 | surface/surfaceSubtle, borderSubtle, radius 16, padding 16/20, elevation 0/1 |
| `AppSelectionCard` | Radio/Checkbox 성격의 큰 선택지 제공 | Profile, Activity, Sleep 환경, Household 선택 | single, multiple; icon/noIcon | `title`, `description`, `leading`, `selected`, `enabled`, `onSelected`, `semanticLabel` | default, hover, focus, selected, disabled, error | Tap/Space/Enter 선택, 선택 상태 Semantics 제공 | 2개는 충분한 폭에서 2 Column 가능, 3개 이상 Wrap/Grid; 200% Text에서 단일 Column | primary50/400, surface, borderDefault, radius 14, minHeight 52, padding 14×16 |
| `AppChip` | 짧은 Category, 상태, Filter Label 표현 | Guide Category, 요청 상태, Report Label | neutral, category, success, warning, error; selected option | `label`, `icon`, `tone`, `selected`, `onSelected` | default, selected, hover/focus when interactive, disabled | Filter인 경우에만 Click, 단순 Label은 비상호작용 | Text 확대 시 폭 증가/Wrap, 생략보다 줄바꿈 우선 | category/semantic foreground+background, radius full, label typography |
| `AppDialog` | 확인·성공·오류 Modal의 공통 Frame 제공 | 초대, 공유, 저장 완료, 재시도 확인 | confirmation, success, error, information | `icon`, `title`, `message`, `primaryAction`, `secondaryAction`, `dismissible`, `semanticLabel` | open, actionLoading, actionError | Focus Trap, Esc/Back 정책, Primary Action 1개 우선 | Mobile은 Page Padding 확보한 폭, Desktop 최대 480; 200% Text에서 Scroll | scrim 42%, surfaceElevated, radius 22, padding 24, modal shadow, icon 40/48 |
| `AppBanner` | 짧은 상태·안내·오류 Message를 일관되게 표시 | Fallback 안내, 의료 비진단 고지, 성공/주의/오류 | info, success, warning, error, neutral | `title`, `message`, `icon`, `action`, `dismissible` | default, dismissing, actionLoading | 선택적 Action과 닫기; 상태를 Live Region으로 알림 | 가로 공간이 부족하면 Action을 다음 줄로 이동 | semantic color/background, surfaceSubtle, radius 14/16, body2/label |
| `AppProgressMetric` | Label과 단계형 수치를 색 외 정보와 함께 표현 | Condition Severity, Health 부위 부담 | 5-step segmented, readOnly, interactive | `label`, `value`, `min`, `max`, `stateLabel`, `onChanged`, `enabled`, `semanticValue` | default, hover/focus when interactive, selected value, disabled, error | Segment Click/Arrow Key 변경, 현재 단계와 Text 상태 안내 | 좁은 폭에서도 Label/상태 Text를 유지하고 Meter만 유연하게 축소 | primary 또는 body category, neutral track, heading/body/label, gap 8/12 |
| `AppSkeleton` | Loading 중 최종 Layout의 크기와 위계를 보존 | Home, Guide, Report, Calendar, List | line, block, circle | `width`, `height`, `radius`, `semanticLabel`, `animate` | loading, reducedMotion | 상호작용 없음; Loading Label 제공 | 부모 Constraint에 맞게 늘어나되 화면 전체 Placeholder 남용 금지 | surfaceSubtle, borderSubtle, component radius, motion 160~220 또는 reduced |

## Design System에 만들지 않는 Wrapper

- `AppText`: `Theme.of(context).textTheme`와 `AppTypography`로 충분하므로 초기에는 만들지 않는다.
- `AppIcon`: `IconTheme`과 `AppIconSize`로 충분하므로 만들지 않는다.
- `AppDivider`: `DividerThemeData`로 충분하므로 만들지 않는다.
- `AppCheckbox`, `AppRadio`: Material Theme와 `AppSelectionCard`로 요구를 충족하므로 독립 Wrapper를 만들지 않는다.
- `AppSpacer`: `AppSpacing` Token을 사용하며 의미 없는 Layout Wrapper를 만들지 않는다.

위 Component는 화면별 중복을 줄일 가치가 높지만, Slot을 무제한 제공하는 하나의 거대 Component로 합치지 않는다. 예를 들어 `AppCard`는 Surface만 담당하고 Meal 추천 구조는 `MealRecommendationCard`가 담당한다.

# 2. Shared Component

Shared Component는 여러 Feature가 공통으로 사용하는 PLM 제품 문법을 제공한다. Feature Controller나 Service에는 의존하지 않고, Route와 데이터는 Props와 Callback으로 전달받는다.

## Component 목록

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `ResponsivePageContent` | Page Padding과 Max Width 중복 제거 | 모든 Page | form, compact, dashboard | `child`, `widthType`, `scrollable`, `bottomPadding` | static | Scroll은 Page 요구에 따라 선택 | Mobile 20, Tablet 28, Desktop 32 Gutter; Max 480/560/720 | AppLayout Width, AppSpacing Page/Section |
| `AppShell` | AppBar, Content, Safe Area, Navigation 조립 | 아내/파트너 Main Shell | standalone, hostEmbedded; with/withoutNavigation | `body`, `appBar`, `navigation`, `currentLocation`, `onDestinationSelected` | destination selected, body loading은 소유하지 않음 | Navigation 선택을 Router Callback으로 전달 | Mobile/Tablet Bottom Nav, Desktop도 IA 유지; Host Shell 제공 시 자체 Nav 제거 | canvas, surface, bottom nav 64~72, safe area, borderSubtle |
| `AppTopBar` | 전역/상세 Header 패턴 통일 | 모든 Page | root, detail, modalLike | `title`, `leading`, `actions`, `showDivider`, `centerTitle` | default, scrolled | Back/Menu/Profile Action 전달 | 높이 56 유지, 긴 Title은 접근 가능한 방식으로 처리 | surface, borderSubtle, detail title 16/600, icon 24, hit 44 |
| `AppBottomNavigation` | 역할별 Destination을 동일한 시각 규칙으로 표현 | Wife Shell, Partner Shell | wifeItems, callerProvidedItems | `items`, `selectedIndex`, `onSelected`, `badges` | default, hover, focus, selected, disabled item | Click/Keyboard 탐색; Route 변경은 외부 Callback | 높이 64~72 + Safe Area; Text 200%에서 Label 잘림 금지 | primary600, textTertiary, icon24, label12, surface |
| `SectionHeader` | Section 제목·설명·보조 Action 정렬 통일 | Home, Guide, Report, Profile Summary | titleOnly, withDescription, withAction | `title`, `description`, `actionLabel`, `onAction`, `semanticHeadingLevel` | default, action states는 AppButton 사용 | 선택적 Text Action | 좁은 폭에서 Action을 다음 줄로 배치 | heading/title2, body2, gap 8/12, textPrimary/Secondary |
| `LoadingState` | Page/Section Loading 표현 | 모든 비동기 Feature | page, section, listSkeleton | `label`, `skeleton`, `preserveHeight` | loading | 상호작용 없음 | Page는 중앙 정렬, Section은 예상 높이 보존 | AppSkeleton, primary progress, spacing 24/32 |
| `EmptyState` | 데이터 없음과 다음 행동 제시 | Calendar, Notification, Report, Guide | compact, page, actionable | `icon`, `title`, `message`, `action` | empty, actionLoading | 선택적 Primary/Secondary Action | Desktop 최대 480, Mobile 폭 채움 | text hierarchy, surfaceSubtle optional, icon40, gap 8/16 |
| `ErrorState` | 실패 이유와 복구 Action 제공 | 모든 비동기 Feature | inline, section, page | `title`, `message`, `retryLabel`, `onRetry`, `technicalId` 제외 | error, retrying | Retry; 민감한 기술 오류는 표시하지 않음 | Inline은 부모 폭, Page는 최대 480 | error/errorBackground, AppBanner/AppButton, radius 16 |
| `CategoryBadge` | 4개 Guide Category를 일관되게 식별 | Routine, Meal, Household, Health, Sleep, Report | meal, household, health, sleep | `category`, `label`, `size`, `showLabel` | default | 기본은 비상호작용 | 좁은 공간에서 Icon-only 사용 시 Tooltip/Semantics 필수 | category foreground/background, icon20/24, radius 10/full |
| `StatusBadge` | 완료·요청·주의 상태를 Text+Icon으로 표시 | Household, Routine, Report, Notification | neutral, pending, acknowledged, complete, warning, error | `label`, `tone`, `icon`, `compact` | static state display | 기본은 비상호작용 | Wrap 가능, Text 생략 금지 | semantic colors/background, label/caption, radius full |
| `GuideTaskCard` | 여러 Guide의 행동·Metadata·완료 Action 구조 통일 | Routine Detail, Household, Health, Sleep, Report | actionable, selectable, readOnly, completed | `title`, `description`, `category`, `status`, `leading`, `action`, `selected`, `onSelected` | default, hover/focus, selected, submitting, completed, disabled | Card 또는 명시 Action만 Click; 전체 Card와 내부 Button 충돌 금지 | Mobile 단일 열, 넓은 폭에서 짧은 Card만 2열 가능 | AppCard, CategoryBadge, radius16, borderSubtle, padding16, status tokens |
| `ConditionSummaryBanner` | 날짜·임신 주차·컨디션 핵심을 짧게 공유 | Routine Home, Meal, Health, Sleep, Chat, Partner Report | compact, detailed | `week`, `date`, `summary`, `tone`, `supportingText` | ready, unavailable | 기본 비상호작용 | 좁은 폭에서 Metadata 줄바꿈, 고정 높이 금지 | surfaceSubtle/primary50, title2/body2, radius16, padding16/20 |
| `MetricCard` | 숫자·Label 요약을 반복 가능한 단위로 제공 | Daily Report, Partner Report, Movement Phase 2 | neutral, success, warning | `label`, `value`, `supportingText`, `icon`, `tone` | ready, unavailable | 필요 시 외부가 `AppCard` Actionable로 감쌈 | Mobile Stack, Tablet 이상 2~3열은 Text Scale 허용 시만 | surface, borderSubtle, title2/body2, radius16, padding16 |
| `PartnerShareResultDialog` | 파트너 공유 성공/실패 결과의 공통 구조 제공 | Meal Share, Household Share, Report Share | success, unavailable, error | `title`, `message`, `partnerName`, `destinationLabel`, `onConfirm`, `onRetry` | success, error, retrying | Confirm/Retry, 닫으면 원래 Context 복귀 | AppDialog의 Max Width와 Scroll 규칙 사용 | AppDialog, primary CTA, success/error, modal radius/shadow |

## Shared Component 공통화 판단

- `LoadingState`, `EmptyState`, `ErrorState`는 구조와 접근성 요구가 반복되므로 공통화한다. 단, 상태 전환을 담당하는 거대 `AsyncView<T>`는 Feature별 State가 확정되기 전 만들지 않는다.
- `GuideTaskCard`는 가사·건강·수면·기록에서 동일한 정보 구조가 반복되므로 공통화한다. Meal의 사진 중심 추천 Card는 구조가 달라 포함하지 않는다.
- `ConditionSummaryBanner`는 여러 Guide가 같은 컨디션 Context를 보여주므로 공통화한다. 컨디션 입력 Control은 `condition` Feature에 남긴다.
- `PartnerShareResultDialog`는 공유 결과 문법만 공통화한다. 무엇을 누구에게 공유할지 결정하는 로직은 각 Feature가 소유한다.
- `AppBottomNavigation`은 Item 목록을 Props로 받는다. 문서에 없는 파트너 Tab 구성을 Component 내부에서 확정하지 않는다.

# 3. Feature Component

Feature Component는 해당 Feature의 Model과 업무 용어를 알 수 있다. Controller를 직접 조회하기보다 가능한 한 State 조각과 Callback을 Props로 받는다.

## Profile

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `ProfileWizardForm` | 6단계 Profile 입력 흐름의 현재 Step 표현 | W-PROFILE-001 최초 등록 | dueDate, body, parity, multiple, allergy, diagnosis | `step`, `draft`, `errors`, `onChanged`, `onNext`, `onBack`, `isSubmitting` | editing, invalid, submitting | 입력/선택, Back/Next; 한 화면 Primary Task 1개 | Form 최대 560, 선택지 2열/Wrap 가능, 짧은 Viewport만 CTA Sticky | AppTextField, AppSelectionCard, AppButton, progress primary, spacing 24/32 |
| `ProfileSummary` | 입력값을 Core/Health/Partner 구획으로 검토 | W-PROFILE-001 요약·수정 | editable, readOnlyPartner | `profile`, `partnerStatus`, `onEditSection`, `onInvite` | ready, missingOptionalData | 수정 가능한 Section만 Action 제공 | Mobile 단일 열, Desktop Form 폭 유지 | AppCard, SectionHeader, InfoBanner, title/body, radius16 |
| `ProfileMenu` | 전역 Profile Action 제공 | Wife 전역 Menu | unlinked, linked | `summary`, `isPartnerLinked`, `onEdit`, `onInvite`, `onSettings` | open, selected | Menu 선택; 연결 완료 시 초대 항목 미노출 | Mobile Bottom Sheet 또는 Menu, Desktop Anchored Menu는 Shell Context에 맞춤 | surfaceElevated, elevation2, radius14/20, hit44 |

## Invitation

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `PartnerInvitePanel` | 연결 가치, 초대 링크와 공유 Action 표시 | W-INVITE-001 | generating, ready, shared, linked, error | `inviteLinkLabel`, `status`, `onGenerate`, `onCopy`, `onShare`, `onLater`, `benefits` | loading, ready, submitting, success, error | Copy/Share/Later; 실제 공유 방식은 Callback | Form 최대 560, Action은 Mobile Stack/충분한 폭에서 Row | AppCard, AppButton, info colors, primary CTA, spacing16/24 |
| `InvitationAcceptancePanel` | 초대 검증과 수락 결과 표현 | H-INVITE-001 | validating, valid, loginRequired, expired, alreadyUsed, duplicateLink, linking, complete | `inviterName`, `status`, `onAccept`, `onRetry`, `onContinue` | loading, ready, submitting, success, error | 수락/재시도/계속; 외부 설치·로그인은 Router가 처리 | Compact 최대 480, 상태 Text가 잘리지 않게 Scroll | AppBanner, AppButton, AppDialog semantics, success/error/info |

## Condition

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `ConditionSelector` | 입덧·통증·피로·기분 등 오늘 상태 입력 | W-COND-001 | create, edit | `conditionDraft`, `availableMetrics`, `errors`, `onMetricChanged`, `onSubmit`, `isSubmitting` | initial, editing, invalid, submitting | Metric과 부위 값 선택, 저장 | Form 최대 560, Metric은 단일 Dominant Column, 200% Text 지원 | AppProgressMetric, AppButton, section gap32, neutral/semantic state |
| `BodyPainSelector` | 부위별 통증 수준 입력 | `ConditionSelector` 내부 | interactive, readOnly | `areas`, `values`, `onChanged`, `enabled` | default, selected, error | 부위별 5단계 선택; Keyboard 순서 유지 | Mobile Stack, 충분한 폭에서도 Label 가독성 우선 | AppProgressMetric, body category, card gap10/12 |
| `PlannedActivitySelector` | 오늘 예정 활동 복수 선택 | W-ACT-001 | create, edit | `options`, `selectedIds`, `onToggle`, `onSubmit`, `isSubmitting` | initial, selected, invalid, submitting | Card 선택/해제, 다음 | Form 최대 560; 2열은 Card Text가 짧고 200% Text가 아닐 때만 | AppSelectionCard, AppButton, primary selected, gap12 |

## Routine / Home

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `PregnancyWeekHero` | 인사, 현재 임신 주차, 주차별 핵심 Tip 표시 | W-ROUTINE-001, H-REPORT-001 일부 | withConditionCta, guideReady, readOnly | `name`, `week`, `message`, `tips`, `onCheckCondition` | ready, conditionMissing | 조건 미입력 때만 CTA | Dashboard 최대 720, 원형 Indicator 비율 유지, 장식 최대 2~3개 | Hero radius20, display, primary600/50, surface, spacing20/24 |
| `DailyCareSection` | 오늘 4개 Guide Summary를 한 흐름으로 조합 | W-ROUTINE-001 | ready, partialComplete, complete, fallback | `guides`, `onGuideSelected`, `onFinishDay`, `onEditCondition`, `isFinishing` | ready, submitting, fallback | Guide 진입, 컨디션 수정, 하루 끝내기 | Mobile Single Column, Desktop도 Main 흐름 단일 Column | SectionHeader, RoutineGuideCard, AppButton, section gap32 |
| `RoutineGuideCard` | Meal/Household/Health/Sleep Summary와 진행 상태 표시 | `DailyCareSection` | meal, household, health, sleep; pending/inProgress/complete | `guide`, `onTap`, `status`, `isFallback` | default, hover/focus, complete, disabled | 전체 Card 진입, 내부 중복 Action 없음 | Content 높이 가변; 4개 Card를 무조건 서로 다른 전체 Pastel로 채우지 않음 | AppCard, CategoryBadge, StatusBadge, borderSubtle, tint icon only |
| `RoutineGenerationState` | AI Routine 생성·지연·Fallback 상태 전달 | W-ROUTINE-001 | generating, delayed, fallback, retrying | `status`, `message`, `onRetry` | loading, warning, error/retrying | Retry는 실패 시에만 | 기존 Home Layout 높이를 가능한 보존 | LoadingState, AppBanner, AppSkeleton, warning/info, motion reduced |

## Meal

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `MealPeriodSelector` | 아침·점심·저녁·간식 추천 진입 선택 | W-MEAL-001 | current, otherPeriod | `periods`, `selected`, `onSelected` | default, selected, disabled | Card 선택/Keyboard | Mobile Stack, 넓은 폭에서 2열 가능 | AppSelectionCard, CategoryBadge meal, gap12 |
| `MealRecommendationCard` | 추천 Menu, 이유, 영양 목적, 이미지 표현 | W-MEAL-001, 식사 재추천 결과 | initial, replacement, accepted | `meal`, `image`, `evidence`, `tags`, `status`, `onAccept`, `onRechoose`, `onShare` | loading, ready, submitting, accepted, error | 수락/재선택/공유; Primary Action 1개 | 이미지 비율 일관, Mobile Stack; Desktop에서도 최대 Content 폭 유지 | AppCard, meal tint/icon, AppChip, AppButton, radius16, borderSubtle |
| `MealCautionSection` | 오늘 피하거나 조절할 식품과 이유 표시 | W-MEAL-001 | list, withAllowance | `items`, `title`, `description` | ready, empty | 기본 비상호작용 | 긴 설명 줄바꿈, Table 형태로 압축하지 않음 | warning/background, body1/body2, icon20, gap10 |
| `MealChatConversation` | 식사 한정 대화와 응답 대기 표현 | W-CHAT-001 | initial, conversation, waiting, failed | `messages`, `quickReplies`, `draft`, `onDraftChanged`, `onSend`, `onQuickReply`, `isResponding` | ready, composing, submitting, error | Message 입력/전송, Quick Reply 최대 2~3개 | Bubble max 78%/84%, 입력부 Safe Area, Desktop Content 720 | user primary500/600, assistant surfaceSubtle, radius16/6, body1 |
| `MealRechoiceCard` | 대화에서 나온 새 추천을 적용 | W-CHAT-001 | proposed, applying, applied | `recommendation`, `onApply`, `onShowAnother` | ready, submitting, success, error | 적용/다른 Menu 보기 | Mobile Action Stack 또는 2개 Row, Card 높이 가변 | AppCard, meal category, AppButton, AppChip, primary CTA |

## Household

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `HouseholdTaskGroup` | 직접 수행·가전 추천·가족 분담 항목을 인간적인 구획으로 표현 | W-HOUSE-001 | direct, applianceRecommendation, family | `title`, `description`, `tasks`, `onTaskAction`, `selection` | ready, partial, complete, disabled | Task Action과 선택을 외부 Callback으로 전달 | Main은 Single Column, 짧은 보조 Task만 Tablet 2열 가능 | SectionHeader, GuideTaskCard, home category, section gap28/32 |
| `HouseholdShareSelector` | 배우자에게 요청할 가사 항목 복수 선택·전송 | W-HOUSE-001 | unlinked, selectable, submitting, shared | `tasks`, `selectedIds`, `partnerName`, `onToggle`, `onShare` | initial, selected, disabled/unlinked, submitting, success, error | 선택/해제/공유, 미연결 안내 | Mobile Single Column, CTA Full Width | AppSelectionCard, AppButton, PartnerShareResultDialog, primary selected |
| `PartnerRequestCard` | 파트너가 요청 이유·가사·상태를 확인하고 처리 | H-REQUEST-001, H-NOTI 진입 결과 | requested, acknowledged, completed | `request`, `onAcknowledge`, `onComplete` | ready, submitting, success, error | 요청 확인, 완료 처리; 허용된 다음 Action만 표시 | Mobile Full Width, Desktop 최대 720; Action은 Text Scale에 따라 Stack | AppCard, StatusBadge, AppButton, home/info/success, radius16 |
| `RequestStatusView` | 아내 화면에 파트너 확인·완료 상태 반영 | W-HOUSE-001, W-REPORT-001 | requested, acknowledged, completed | `status`, `partnerName`, `updatedAt`, `compact` | live/readOnly, unavailable | 비상호작용, 상태 변경 시 Semantics 안내 | Compact는 한 줄 우선하되 Wrap 허용 | StatusBadge, info/success, body2/caption |

## Health

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `BodyLoadSummary` | 컨디션 기반 부위별 부담과 집중 부위 표시 | W-HEALTH-001 | conditionBased, motionEnhancedPhase2 | `areas`, `focusArea`, `sourceLabel` | ready, unavailable | 기본 비상호작용 | Mobile Stack, Tablet에서 짧은 Metric 2열 가능 | body category, AppProgressMetric readOnly, Info text, gap12 |
| `HealthActivityCard` | 스트레칭·산책·마사지 콘텐츠와 완료 Action 제공 | W-HEALTH-001 | featured, compact, completed | `activity`, `thumbnail`, `onOpen`, `onComplete` | ready, loadingMedia, submitting, completed, error | 콘텐츠 보기, 완료 체크 | Featured는 Full Width, Compact List; 이미지 없으면 무작위 Placeholder 생성 금지 | AppCard/GuideTaskCard, body tint, AppButton, radius16 |

## Sleep

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `SleepEnvironmentSelector` | 조명·온도·습도·소리·공기청정기 추천값 선택·조정 | W-SLEEP-001 | recommended, editing, completed | `items`, `selectedIds`, `onToggle`, `onEditValue`, `onStart`, `isSubmitting` | ready, selected, editing, submitting, completed, error | 복수 선택, 값 수정, MVP 수행 기록 시작 | Mobile 1~2열은 가용 폭 기준, Tablet 2열; 200% Text에서는 1열 | AppSelectionCard, sleep foreground/background, AppButton primary, gap12 |
| `SleepTipList` | 오늘의 수면 행동 Tip 전달 | W-SLEEP-001 | standard | `tips`, `sourceLabel` | ready, empty | 비상호작용 | Single Column, 긴 Text 자연 줄바꿈 | success/info icon+text, body1, gap12 |

## Report

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `DailyReportSummary` | 날짜·주차·완료 수치 요약 | W-REPORT-001 | inProgress, completed, historical | `date`, `week`, `metrics`, `status` | loading, ready, empty | 기본 비상호작용 | Mobile Stack, Tablet 이상 Metric 2~3열은 Text Scale 허용 시 | ConditionSummaryBanner, MetricCard, title/body, gap12 |
| `RoutineRecordList` | 수행·건너뜀·파트너 완료 내역 표시 | W-REPORT-001, H-CAL-001 상세 | wifeEditableBeforeFinish, readOnly | `records`, `onRecordSelected` | loading, ready, empty, error | 필요 시 Detail 진입; 완료 결과 자체는 읽기 전용 | Single Column, Category/상태 Label Wrap | GuideTaskCard readOnly, CategoryBadge, StatusBadge, gap10 |
| `FamilyParticipationSummary` | 요청·확인·완료 수치와 메시지 요약 | W-REPORT-001, H-REPORT-001 | compact, detailed | `requested`, `acknowledged`, `completed`, `message` | ready, empty | 비상호작용 | Mobile Stack 또는 행, Tablet Metric Grid | infoBackground, success, MetricCard, radius16 |
| `ConditionCalendar` | 날짜별 컨디션 수준과 선택일 탐색 | W-CAL-001, H-CAL-001 | wife, partnerReadOnly | `month`, `days`, `selectedDate`, `onDateSelected`, `onPreviousMonth`, `onNextMonth` | loading, ready, emptyMonth, error | 월 이동, 날짜 선택, Keyboard Grid 탐색 | Content 최대 720; Cell 최소 Hit 44, Text 200%에서 Calendar와 Detail 분리/Stack | primary selected ring, 상태 dot/ring/tint, legend, borderSubtle |
| `PartnerMorningSummary` | 파트너에게 임신 주차·컨디션·예정 활동·4개 Guide 요약 전달 | H-REPORT-001 | linked, noSharedData, partial | `report`, `onRequestSelected`, `onCalendarSelected` | loading, ready, empty, error | 요청 또는 Calendar 진입 | Mobile Single Column, Desktop Secondary Summary 2열 가능 | ConditionSummaryBanner, CategoryBadge, GuideTaskCard readOnly, info |

## Notification

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `NotificationListItem` | Report 도착·가사 요청·미완료 알림을 읽음 상태와 함께 표시 | H-NOTI-001 | report, request, reminder; read/unread | `notification`, `onTap`, `onMarkRead` | default, hover/focus, unread, read, disabled | 항목 선택 후 목적 Route로 이동, 읽음 Callback | Mobile Full Width List, Desktop 최대 720; Timestamp 줄바꿈 허용 | AppCard, StatusBadge, primary small indicator, body1/caption |

## Movement (Phase 2)

| Name | Purpose | Used In | Variants | Props | State | Interaction | Responsive Behavior | Design Token |
|---|---|---|---|---|---|---|---|---|
| `MovementStatusPanel` | Sensor 연결·감지 상태와 핵심 Metric 표시 | 향후 W-MOTION-001 | disconnected, connecting, calibrating, live, error | `connectionState`, `duration`, `recommendation`, `onToggle` | 기존 Movement Controller 상태 Mapping | 시작/중지, 권한/오류 안내 | Camera Preview와 충돌하지 않게 Stack, Desktop 최대 720 | info/success/warning/error, MetricCard, AppButton |
| `RealtimeAlertCard` | 위험 행동 Log의 시간·유형·행동 안내 표시 | 향후 W-MOTION-001 | warning, highAttention, resolved | `event`, `onTap` | default, hover/focus, resolved | Detail 진입 가능; 색만으로 심각도 표시 금지 | Single Column List, Timestamp와 Action Wrap | semantic icon shape+color+text, AppCard, radius16 |

현재 `movement_screen.dart`, `MovementOverlayPainter`, Private `_PostureBadge`는 이미 존재한다. `MovementOverlayPainter`는 Canvas Rendering Helper이며 공통 UI Component로 승격하지 않는다. `_PostureBadge`도 데모 전용이므로 지금 이동하거나 공통화하지 않는다. 위 두 신규 Component는 Phase 2 제품화 시에만 만든다.

# 중복 및 공통화 분석

## 기존 Component와 중복 여부

현재 제품 공통 Component는 구현되어 있지 않다. `app.dart`와 `movement_screen.dart`는 Material 기본 `Card`, `FilledButton`, `Chip`, `AppBar`, `Padding`, `TextStyle`, `Color`를 직접 사용한다.

| 기존 코드 | 새 Component와의 관계 | 결정 |
|---|---|---|
| `Card` in `app.dart` | `AppCard`와 시각 책임이 겹침 | 임시 화면 제거 시 함께 사라지므로 별도 Migration 대상이 아님 |
| `FilledButton` in `movement_screen.dart` | `AppButton`과 Action 상태가 겹침 | Phase 2 제품화 전까지 기존 데모를 유지하고 선제 교체하지 않음 |
| `Chip` / `_PostureBadge` | `StatusBadge`와 시각적으로 유사 | Backend Enum과 강하게 결합된 데모 Private Widget이므로 공통화하지 않음 |
| `AppBar` in 기존 화면 | `AppTopBar`와 책임이 겹침 | 제품 Page 구현 시 `AppTopBar` 사용, Movement Demo는 Phase 2 때 적용 |
| `MovementOverlayPainter` | 대응 공통 Component 없음 | Rendering 전용으로 유지 |

따라서 기존 코드를 대규모로 변환하지 않고, 신규 제품 UI부터 Component System을 적용한다.

## 공통화할 가치가 높은 항목

- Action 상태와 접근성을 한 번에 보장하는 `AppButton`, `AppIconButton`
- 입력·선택 오류 표현이 반복되는 `AppTextField`, `AppSelectionCard`
- Border/Radius/Interaction이 반복되는 `AppCard`
- 모든 화면에 필요한 `ResponsivePageContent`, `AppTopBar`, `AppShell`
- 비동기 화면에 반복되는 `LoadingState`, `EmptyState`, `ErrorState`
- Guide와 Report에 반복되는 `CategoryBadge`, `StatusBadge`, `GuideTaskCard`
- 여러 Guide가 같은 당일 상태 Context를 공유하는 `ConditionSummaryBanner`

## Feature 내부가 더 적절한 항목

- `ProfileWizardForm`: Step, Draft, Validation이 Profile에만 존재한다.
- `MealRecommendationCard`: 이미지, 영양 Tag, 추천 이유, 재선택 Action이 Meal 전용이다.
- `HouseholdTaskGroup`과 `PartnerRequestCard`: 요청 상태 전이가 Household Domain에 속한다.
- `SleepEnvironmentSelector`: 환경 항목과 추천값 편집은 Sleep 전용이다.
- `ConditionCalendar`: 날짜 Cell이 일반 Calendar가 아니라 컨디션 단계와 Report 연결을 안다.
- `MealChatConversation`: 현재 요구사항이 식사 재조정으로 제한되어 있어 범용 Chat Component로 만들지 않는다.
- `MovementStatusPanel`: 기존 Camera/Connection State와 결합되며 Phase 2다.

## 의도적으로 합치지 않는 Component

- `RoutineGuideCard`와 `GuideTaskCard`: 전자는 Home 진입용 Summary, 후자는 수행 가능한 Task다.
- `MealRecommendationCard`와 `GuideTaskCard`: 사진·근거·영양 Tag·재추천 구조가 다르다.
- `ConditionSummaryBanner`와 `PregnancyWeekHero`: 전자는 재사용 Context Summary, 후자는 Home의 Signature Hero다.
- `StatusBadge`와 `AppChip`: 전자는 제품 상태 의미를 Mapping하고, 후자는 시각 Primitive다.
- `PartnerInvitePanel`과 `InvitationAcceptancePanel`: 발신과 수락은 상태와 Primary Action이 다르다.
- `LoadingState`, `EmptyState`, `ErrorState`: 초기에는 단순한 각각의 Presentational Component로 유지하고 복잡한 Generic Wrapper로 합치지 않는다.

# Component API 규칙

1. Props는 가능한 한 `required`로 명시하고 의미 없는 Nullable Flag 조합을 피한다.
2. Boolean Props가 3개 이상 결합해 Variant를 만들면 명시적인 Enum 또는 Model로 바꾼다.
3. Component는 Controller, Service, Router를 직접 찾지 않는다.
4. Component는 `onTap`, `onSubmit`, `onRetry` 같은 사용자 Intent Callback만 외부로 전달한다.
5. `BuildContext`를 비동기 Callback 이후 저장하거나 재사용하지 않는다.
6. State는 Parent/Controller가 소유하는 Controlled Component를 기본으로 한다.
7. Text, Icon, Status는 Semantics Label을 제공하고 색만으로 의미를 전달하지 않는다.
8. Click 가능한 Container는 `InkWell` 또는 동등한 Focus/Keyboard/Mouse 지원을 포함한다.
9. 전체 Card Click과 내부 Button을 동시에 두어 동일 Gesture가 중복 실행되지 않게 한다.
10. 고정 높이는 Button/Input 등 규격이 필요한 Control에만 사용하고 Content Card에는 사용하지 않는다.
11. `MediaQuery` 전체 폭이 아니라 부모 Constraint를 기준으로 Component Layout을 바꾼다.
12. 200% Text Scale에서 2 Column이 불가능하면 Single Column으로 전환한다.
13. 직접 `Color`, `TextStyle`, `EdgeInsets`, `BorderRadius`를 생성하지 않고 Design Token을 사용한다.
14. Feature Component가 Category Color를 Primary CTA Background로 사용하지 않는다.
15. Loading, Empty, Error를 정상 Content와 같은 위치에서 교체해 Layout Jump를 최소화한다.
16. 의료·건강 정보는 진단으로 단정하지 않고 추천·참고 문구와 Source Label을 구분한다.

# 파일 배치 제안

실제 구현 시 필요한 Component만 점진적으로 생성한다.

```text
frontend/lib/
├─ design_system/components/
│  ├─ app_button.dart
│  ├─ app_icon_button.dart
│  ├─ app_text_field.dart
│  ├─ app_card.dart
│  ├─ app_selection_card.dart
│  ├─ app_chip.dart
│  ├─ app_dialog.dart
│  ├─ app_banner.dart
│  ├─ app_progress_metric.dart
│  └─ app_skeleton.dart
├─ widgets/
│  ├─ responsive_page_content.dart
│  ├─ app_shell.dart
│  ├─ app_top_bar.dart
│  ├─ app_bottom_navigation.dart
│  ├─ section_header.dart
│  ├─ loading_state.dart
│  ├─ empty_state.dart
│  ├─ error_state.dart
│  ├─ category_badge.dart
│  ├─ status_badge.dart
│  ├─ guide_task_card.dart
│  ├─ condition_summary_banner.dart
│  ├─ metric_card.dart
│  └─ partner_share_result_dialog.dart
└─ features/{feature}/widgets/
   └─ 해당 Feature Component
```

`03_design_system.md`에서 `core/responsive/responsive_content.dart`로 제안했던 이름은 역할을 더 분명히 하기 위해 구현 시 `widgets/responsive_page_content.dart` 하나로 통합한다. 동일 목적의 두 파일을 만들지 않는다. Breakpoint Token은 `core/responsive/app_breakpoints.dart`에 유지한다.

# 구현 우선순위

전체 Page를 동시에 만들지 않고 아래 순서로 Component를 검증한 뒤 Feature 화면에 적용한다.

## 1. Foundation Component

1. Design Token과 `AppTheme`
2. `AppButton`
3. `AppIconButton`
4. `AppTextField`
5. `AppCard`
6. `AppSelectionCard`
7. `AppChip`
8. `AppBanner`
9. `AppDialog`
10. `AppProgressMetric`
11. `AppSkeleton`

검증 기준:

- Default, Hover, Focus, Pressed, Selected, Disabled, Loading, Error 상태
- 최소 44×44 Hit Area
- Keyboard와 Screen Reader Label
- 200% Text Scale
- Token 외 임의 Style 값 사용 여부

## 2. Shared Component

1. `ResponsivePageContent`
2. `AppTopBar`
3. `AppBottomNavigation`
4. `AppShell`
5. `SectionHeader`
6. `LoadingState`, `EmptyState`, `ErrorState`
7. `CategoryBadge`, `StatusBadge`
8. `ConditionSummaryBanner`
9. `MetricCard`
10. `GuideTaskCard`
11. `PartnerShareResultDialog`

검증 기준:

- Mobile/Tablet/Desktop Content Width와 Padding
- Shell과 Browser Back/Keyboard Navigation
- 역할별 Item을 주입할 수 있고 Partner Tab을 임의 확정하지 않는지
- 비동기 상태에서 Layout Shift가 과도하지 않은지

## 3. Feature Component

사용자 핵심 흐름과 의존 순서에 따라 구현한다.

1. Profile: `ProfileWizardForm` → `ProfileSummary` → `ProfileMenu`
2. Invitation: `PartnerInvitePanel` → `InvitationAcceptancePanel`
3. Condition: `BodyPainSelector` → `ConditionSelector` → `PlannedActivitySelector`
4. Routine: `PregnancyWeekHero` → `RoutineGuideCard` → `RoutineGenerationState` → `DailyCareSection`
5. Meal: `MealPeriodSelector` → `MealRecommendationCard` → `MealCautionSection` → `MealChatConversation` → `MealRechoiceCard`
6. Household: `HouseholdTaskGroup` → `HouseholdShareSelector` → `PartnerRequestCard` → `RequestStatusView`
7. Health: `BodyLoadSummary` → `HealthActivityCard`
8. Sleep: `SleepEnvironmentSelector` → `SleepTipList`
9. Report: `DailyReportSummary` → `RoutineRecordList` → `FamilyParticipationSummary` → `ConditionCalendar` → `PartnerMorningSummary`
10. Notification: `NotificationListItem`
11. Movement Phase 2: `MovementStatusPanel` → `RealtimeAlertCard`

각 단계에서는 Component 단독 Widget Test와 접근성 상태를 먼저 검증한 후 Page에 조립한다. Movement는 MVP Component 구현 목록에서 제외하고 기존 데모를 유지한다.

# 이번 STEP 변경 범위

이번 STEP 4에서는 다음 문서만 생성·갱신한다.

```text
docs/development/04_component_system.md
docs/development/frontend_workflow.md
```

Flutter Component, Page, Package는 생성하거나 수정하지 않는다.

