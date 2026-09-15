# Color System

## 원칙

- `DESIGN.md`의 Product Palette를 단일 Source로 사용한다.
- 화면에서 강한 Accent 계열은 하나만 사용한다.
- Primary는 CTA, 선택 상태, 핵심 데이터에 한정한다.
- Category Color는 버튼 전체가 아니라 Icon, Label, Indicator, 작은 Tint 영역에 사용한다.
- 상태는 색만으로 전달하지 않고 Icon과 Text Label을 함께 제공한다.
- Dark Theme는 문서에 정의되어 있지 않으므로 이번 Design System 범위에 추가하지 않는다.

## Primary

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.primary50` | `#FFF2F5` | 선택 배경, 매우 약한 Primary Tint |
| `AppColors.primary100` | `#FCE4EA` | Focus Ring, 강조 배경 |
| `AppColors.primary200` | `#F6C6D2` | 약한 강조 Border |
| `AppColors.primary300` | `#EFA2B5` | 보조 강조 |
| `AppColors.primary400` | `#E47A98` | 선택 Border |
| `AppColors.primary500` | `#D95B7F` | Input Focus Border, 중간 강조 |
| `AppColors.primary600` | `#C6426A` | 기본 Primary CTA, 선택 Navigation, 핵심 데이터 |
| `AppColors.primary700` | `#A93257` | Web Hover |
| `AppColors.primary800` | `#842642` | Pressed |
| `AppColors.primary900` | `#621C31` | 가장 강한 Primary Text/Container 대비가 필요할 때 제한 사용 |

`LG Active Red #FD312E`와 `LG Heritage Red #A50034`는 Brand Reference이며 일반 CTA Token으로 만들지 않는다.

## Secondary

`DESIGN.md`에는 Primary와 경쟁하는 별도의 Product Secondary Hue가 정의되어 있지 않다. 따라서 새로운 Secondary 색상을 임의로 추가하지 않는다.

- Flutter의 `ColorScheme.secondary`는 `AppColors.primary600`에 정렬한다.
- `secondaryContainer` 역할은 `AppColors.primary100`을 사용한다.
- 수면의 Purple 등 Category Color를 Product Secondary나 공통 CTA에 사용하지 않는다.
- 시각적 2순위 Action은 색을 바꾸는 대신 White Surface, Border, Primary/Text Color를 사용하는 `SecondaryButton`으로 표현한다.

## Background

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.canvas` | `#F8F7F5` | Scaffold와 전체 Page 배경 |
| `AppColors.surfaceSubtle` | `#F5F3F1` | Section 구획, 약한 상태 배경, Skeleton 기반 면 |

## Surface

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.surface` | `#FFFFFF` | Card, Input, 기본 Modal |
| `AppColors.surfaceElevated` | `#FFFFFF` | Floating Menu, Dialog 등 Shadow가 있는 Surface |

같은 Hex여도 `surface`와 `surfaceElevated`는 Elevation 의미가 다르므로 Token을 분리한다.

## Text

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.textPrimary` | `#1F1F1F` | 제목, 본문, 핵심 데이터 |
| `AppColors.textSecondary` | `#65615F` | 보조 설명, Metadata |
| `AppColors.textTertiary` | `#8A8582` | Caption, 비활성에 가깝지만 읽어야 하는 보조 정보 |
| `AppColors.textInverse` | `#FFFFFF` | Primary CTA 등 검증된 진한 배경 위 Text |
| `AppColors.textDisabled` | `#AAA6A3` | Disabled Label과 Icon |

긴 본문은 `textTertiary`보다 낮은 대비를 사용하지 않는다.

## Border

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.borderSubtle` | `#E9E5E2` | 일반 Card, 조건부 AppBar Divider |
| `AppColors.borderDefault` | `#DDD8D5` | Input, Secondary Button, 명확한 Surface 경계 |
| `AppColors.borderStrong` | `#C9C3BF` | 강한 구분, Disabled/Fallback Border |

Focus, Selected, Error Border는 별도 Neutral Border가 아니라 각각 Primary 또는 Semantic Token을 사용한다.

## Disabled

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.disabledFill` | `#E4E0DE` | Disabled Button Background |
| `AppColors.textDisabled` | `#AAA6A3` | Disabled Text/Icon |
| `AppColors.borderDisabled` | `#C9C3BF` | Disabled Control Border |

Disabled 상태에서도 Label이 사라지지 않아야 하며, 비활성 이유가 필요한 경우 보조 Text를 함께 제공한다.

## Success

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.success` | `#357861` | 완료 Icon, 완료 Label, 성공 상태 |
| `AppColors.successBackground` | `#EDF6F1` | 성공 Banner와 작은 Tint 영역 |

## Warning

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.warning` | `#9A6A17` | 주의 Icon과 Label |
| `AppColors.warningBackground` | `#FBF5E8` | 주의 Banner와 상태 영역 |

## Error

| Token | Hex | 용도 |
|---|---:|---|
| `AppColors.error` | `#B64048` | 오류 Text, Border, Icon |
| `AppColors.errorBackground` | `#FBEEEE` | 오류 Banner와 Inline Error 배경 |

`DESIGN.md`의 `danger`를 Flutter의 표준 명칭인 `error`로 Mapping한다. 의료적 위험 상태를 과장하는 용도가 아니라 입력 실패, 요청 실패, 확인이 필요한 오류 표현에 사용한다.

## Info와 Category 보조 Token

요청된 기본 Color System 외에도 Requirements의 Guide Category와 상태 표현을 위해 `DESIGN.md`에 명시된 Token을 유지한다.

| Group | Foreground | Background | 제한된 용도 |
|---|---:|---:|---|
| Info | `#416C8A` | `#EEF4F8` | 일반 정보 Banner |
| Meal | `#5F846A` | `#EEF5EF` | 식사 Icon, Label, Indicator |
| Home | `#A85B70` | `#FAF0F3` | 가사 Icon, Label, Indicator |
| Body | `#5C7191` | `#EEF2F8` | 건강 Icon, Label, Indicator |
| Sleep | `#7560A3` | `#F2EFF8` | 수면 Icon, Label, Indicator |

권장 코드 Token은 `AppColors.info`, `infoBackground`, `meal`, `mealBackground`, `home`, `homeBackground`, `body`, `bodyBackground`, `sleep`, `sleepBackground`다.

# Typography

## Font Family

```text
Pretendard Variable
→ Noto Sans KR
→ system sans-serif
```

- ThinQ Host App의 사내 Font가 제공되면 그 Font를 최우선으로 한다.
- 현재 `pubspec.yaml`에는 Pretendard Asset이 등록되어 있지 않다. 실제 Font 파일이 제공되기 전에는 시스템 Sans-serif Fallback을 사용하며 임의 Font 파일을 추가하지 않는다.
- Flutter 구현 시 `fontFamilyFallback`에 `Noto Sans KR`와 Platform Sans-serif 계열을 연결한다.

## Type Scale

| Category | Token | Size | Line Height | Weight | 주요 용도 |
|---|---|---:|---:|---:|---|
| Display | `AppTypography.display` | 28 | 38 | 700 | 임신 주차, 핵심 Hero 수치와 메시지 |
| Title | `AppTypography.title1` | 24 | 34 | 700 | Page Title, 큰 Section Title |
| Title | `AppTypography.title2` | 20 | 29 | 700 | Card Group Title, 주요 Content Title |
| Heading | `AppTypography.heading` | 18 | 27 | 700 | Section Heading, 중요한 Card Title |
| Body | `AppTypography.body1` | 16 | 25 | 400 | 주요 본문과 상태 설명 |
| Body | `AppTypography.body2` | 14 | 22 | 400 | 보조 본문과 Metadata |
| Label | `AppTypography.label` | 13 | 19 | 600 | Field Label, Chip, 상태 Label |
| Caption | `AppTypography.caption` | 12 | 18 | 400 | Timestamp, Helper, Caption |

Flutter의 `TextStyle.height`는 `lineHeight / fontSize`로 계산한다. 예를 들어 Body 1은 `25 / 16`을 사용한다.

## Component Typography

- Primary Button은 `15px / 600`을 Component Theme에서 정의한다.
- Bottom Navigation Label은 `11~12px` 범위에서 12px을 기본값으로 사용하고 200% 확대를 고려해 고정 높이로 자르지 않는다.
- Detail AppBar Title은 `16px / 600`을 기본값으로 사용한다.
- 본문 최소 크기는 14px, 주요 상태는 16px 이상을 지킨다.
- Bold는 제목, 상태, 핵심 숫자에만 사용하며 한 Card 안에서 Bold 단계는 최대 2개다.

## Material TextTheme Mapping

| App Token | Material `TextTheme` |
|---|---|
| `display` | `displaySmall` |
| `title1` | `headlineSmall` |
| `title2` | `titleLarge` |
| `heading` | `titleMedium` |
| `body1` | `bodyLarge` |
| `body2` | `bodyMedium` |
| `label` | `labelLarge` |
| `caption` | `bodySmall` |

Material 이름을 화면에서 직접 사용하기보다 의미가 분명한 `AppTypography` Token을 우선하며, Theme를 사용하는 기본 Material Component에는 위 Mapping을 적용한다.

# Spacing Scale

## Base Scale

`DESIGN.md`의 4pt Grid를 그대로 사용한다.

| Token | Value | 사용 예 |
|---|---:|---|
| `AppSpacing.xs` | 4 | Icon 내부 간격, 매우 작은 보정 |
| `AppSpacing.sm` | 8 | Title과 Supporting Text, 작은 Inline Gap |
| `AppSpacing.md` | 12 | Card 간격, Icon과 Text |
| `AppSpacing.lg` | 16 | 일반 Card Padding, Field 간격 |
| `AppSpacing.xl` | 20 | Mobile Page Padding, 넓은 Card Padding |
| `AppSpacing.xxl` | 24 | AppBar와 Page Title, Bottom 안전 여백 |
| `AppSpacing.xxxl` | 32 | 큰 Section 간격 |
| `AppSpacing.space40` | 40 | 매우 큰 화면 구획 |
| `AppSpacing.space48` | 48 | 독립된 큰 Section 또는 Empty State 여백 |

## Semantic Spacing

| Token | Value | 근거와 용도 |
|---|---:|---|
| `AppSpacing.pageMobile` | 20 | Mobile 좌우 Page Padding |
| `AppSpacing.pageTablet` | 28 | Tablet 좌우 Page Padding |
| `AppSpacing.pageDesktop` | 32 | Desktop 최소 Gutter. Base Scale 32에서 파생 |
| `AppSpacing.sectionMin` | 28 | Section 간 최소 간격 |
| `AppSpacing.sectionMax` | 36 | Section 간 최대 간격 |
| `AppSpacing.headingToContentMin` | 12 | Heading과 Content |
| `AppSpacing.headingToContentMax` | 16 | Heading과 Content |
| `AppSpacing.cardGapMin` | 10 | Card 간 최소 간격 |
| `AppSpacing.cardGapMax` | 12 | Card 간 최대 간격 |
| `AppSpacing.cardPaddingMin` | 16 | Card 내부 최소 Padding |
| `AppSpacing.cardPaddingMax` | 20 | Card 내부 최대 Padding |

28, 36, 10은 `DESIGN.md`의 Vertical Rhythm과 Page Margin에 직접 명시된 값이다. 화면에서 Range를 임의로 선택하지 않고 Component 또는 Layout Token이 하나의 값을 결정하도록 한다.

# Radius

## Base Radius

| Token | Value | 용도 |
|---|---:|---|
| `AppRadius.xs` | 6 | 작은 Inline Surface, Bubble Corner Variation |
| `AppRadius.sm` | 10 | Inline Action |
| `AppRadius.md` | 14 | Standard Control과 기본 Button |
| `AppRadius.lg` | 18 | 큰 Card와 Hero 하한 |
| `AppRadius.xl` | 24 | 큰 Modal 상한 |
| `AppRadius.full` | 999 | Chip, Tag, Status Pill만 |

## Component Radius

| Token | Value | 적용 대상 |
|---|---:|---|
| `AppRadius.input` | 12 | InputField |
| `AppRadius.card` | 16 | Standard Card |
| `AppRadius.hero` | 20 | HeroStatusCard |
| `AppRadius.modal` | 22 | Modal/Dialog |
| `AppRadius.button` | 14 | Primary/Secondary Button |

모든 Card와 Button에 `full`을 사용하지 않는다. Hero, Card, Input, Inline Action 간 Radius 차이를 유지한다.

# Elevation / Shadow

기본 Surface 구분은 Border이며 Shadow는 보조 수단이다.

| Token | CSS Reference | Flutter Mapping | 용도 |
|---|---|---|---|
| `AppElevation.none` | none | 빈 `BoxShadow` List | 일반 Card 기본값 |
| `AppElevation.level1` | `0 1px 2px rgba(25,20,18,0.05)` | Offset(0,1), Blur 2 | Web Hover Card, 약한 Floating Surface |
| `AppElevation.level2` | `0 6px 20px rgba(25,20,18,0.08)` | Offset(0,6), Blur 20 | Floating Menu |
| `AppElevation.modal` | `0 14px 40px rgba(25,20,18,0.16)` | Offset(0,14), Blur 40 | Modal/Dialog |

- 일반 Card는 `borderSubtle + AppElevation.none`을 사용한다.
- Hover 가능한 Web Card만 160~220ms 동안 `none → level1`로 전환할 수 있다.
- Modal Dim은 `rgba(0,0,0,0.42)`를 `AppColors.scrim`으로 정의한다.
- Shadow를 Card 계층의 기본 구분 수단으로 사용하지 않는다.

# Icon

## 스타일

- 기본 크기는 20px 또는 24px이다.
- Line Icon, Rounded Cap과 Rounded Join, 시각적 Stroke 1.7~2.0을 기준으로 한다.
- 기본 Material Icon 사용 시 `Icons.*_outlined` 계열을 우선한다.
- Filled Icon은 Bottom Navigation Selected와 핵심 상태에만 사용한다.
- Icon-only Button은 44×44px 이상의 Hit Area와 `Tooltip`, `Semantics` Label을 제공한다.
- Emoji를 기능 Icon으로 사용하지 않는다.
- AI 기능은 Sparkle Icon만으로 나타내지 않고 `AI 추천`, `상태 기반 추천` Text Label을 함께 사용한다.

## Size Token

| Token | Value | 용도 |
|---|---:|---|
| `AppIconSize.sm` | 20 | Inline Icon, 작은 상태 Icon |
| `AppIconSize.md` | 24 | Navigation, 일반 Action |
| `AppIconSize.lg` | 40 | Modal 상태 Icon 하한 |
| `AppIconSize.xl` | 48 | Modal 상태 Icon 상한 |

## Category Mapping

| Domain | Icon 의미 | Color Token |
|---|---|---|
| Meal | bowl, utensils, leaf | `AppColors.meal` |
| Household | home, laundry, cart | `AppColors.home` |
| Health | heart-pulse, body, stretch | `AppColors.body` |
| Sleep | moon, bed | `AppColors.sleep` |
| Report | calendar-check, clipboard | 기본 Text 또는 Info |
| Movement | activity, sensor, notification | 상태에 맞는 Semantic Color |
| Chat | message | Primary, Sparkle은 보조만 |

# Layout

## Content Width

| Token | Value | 적용 화면 |
|---|---:|---|
| `AppLayout.compactContentMaxWidth` | 480 | 짧은 확인/Modal 성격의 Page Content |
| `AppLayout.formContentMaxWidth` | 560 | Profile, Condition, Activity 등 Form/Onboarding |
| `AppLayout.tabletContentMaxWidth` | 680 | Tablet의 넓은 Content |
| `AppLayout.dashboardContentMaxWidth` | 720 | Home, Guide, Report, Calendar |

- Form의 실제 권장 폭은 520~560px이며 최대값은 560px으로 제한한다.
- Desktop에서 Mobile 화면을 좁게 중앙에 복제하지 않는다.
- 주 작업은 단일 Dominant Column을 유지하고 보조 정보만 2 Column을 허용한다.

## Page Padding

| Viewport | Horizontal Padding | Vertical 기본 시작 |
|---|---:|---:|
| Mobile `<600` | 20 | AppBar 이후 24~28 |
| Tablet `600~1023` | 28 | AppBar 이후 24~28 |
| Desktop `>=1024` | 최소 32 | Max Width 내부에서 24~28 |

Bottom Navigation 위 Content는 Safe Area를 포함해 최소 24px 여백을 확보한다.

## Section Gap

- 기본 Section Gap은 32px을 사용한다.
- 밀접한 Section은 28px, 명확히 분리된 Section은 36px까지 허용한다.
- Page에서 숫자를 직접 선택하지 않고 `sectionMin`, `section`, `sectionMax`의 의미 Token을 사용한다.

## Component Gap

- Heading → Content: 12~16px
- Card → Card: 10~12px
- Icon → Text: 12px 기본
- Card 내부 Padding: 16~20px
- Title → Supporting Copy: 8px

## Layout Component

`ResponsiveContent`가 Max Width와 Page Padding을 담당하고 각 Page는 동일한 `Center → ConstrainedBox → Padding` 구조를 반복하지 않는다. `AppShell`은 Top AppBar, Safe Area, Bottom Navigation과 Scroll Content 영역을 조립한다.

# Responsive

## Breakpoints

| Token | Range |
|---|---|
| `AppBreakpoints.mobile` | `0~599` |
| `AppBreakpoints.tablet` | `600~1023` |
| `AppBreakpoints.desktop` | `1024~1439` |
| `AppBreakpoints.wide` | `1440+` |

Breakpoint 판정은 `MediaQuery.sizeOf(context).width` 또는 `LayoutBuilder`의 실제 가용 폭을 기준으로 한다. Component 내부 배치는 가능하면 `LayoutBuilder`를 사용한다.

## Mobile-width Web

- Single Column을 사용한다.
- Bottom Navigation을 유지한다.
- 주요 CTA는 Full Width를 허용한다.
- Profile Onboarding은 Question → Control → CTA의 한 가지 Primary Task만 보여준다.
- Guide와 Report Metric은 세로로 쌓는다.
- 짧은 Viewport에서만 CTA를 Safe Area 위에 Sticky 처리한다.
- Horizontal Scroll에 의존하지 않는다.

## Tablet-width Web

- Content 폭을 560~680px로 제한하고 중앙 정렬한다.
- Main Task는 Single Column을 유지한다.
- 독립적인 Metric, 수면 환경 Card, 짧은 Task Card는 내용과 Text Scale이 허용할 때 2 Column을 사용할 수 있다.
- Bottom Navigation 또는 ThinQ Host Shell을 유지한다.
- 200% Text Scale에서 2 Column이 깨지면 Single Column으로 되돌린다.

## Desktop Web

- Dashboard/Home/Guide는 최대 720px, Form은 최대 560px로 제한한다.
- Viewport를 채우기 위해 Main Task 영역을 과도하게 늘리지 않는다.
- Main Task는 Single Dominant Column을 유지한다.
- Calendar Summary, Metric, Secondary Information만 2 Column을 허용한다.
- Mouse Hover와 Keyboard Focus를 제공한다.
- Wide `>=1440`에서도 Main Content Max Width는 유지한다. 문서에 정의되지 않은 Side Navigation이나 3 Column Layout을 임의로 추가하지 않는다.

## Responsive Navigation

- 독립 실행 모드는 Mobile/Tablet에서 Bottom Navigation을 사용한다.
- Desktop에서도 문서에 정의된 Information Architecture를 유지하며 Side Rail로 자동 변경하지 않는다.
- ThinQ Host Navigation이 제공되면 자체 Shell보다 Host Shell을 우선한다.
- Bottom Navigation 높이는 64~72px와 Safe Area를 포함한다.

# UI State

## 공통 상태 정의

| State | 시각 변화 | 동작 | 접근성 |
|---|---|---|---|
| Default | 기본 Surface, Border, Text Token | 정상 상호작용 | Role과 Label 제공 |
| Hover | Primary CTA `600→700`, Hover Card Elevation `0→1` | Pointer가 있는 Web에서만 | Hover만으로 정보 노출 금지 |
| Focus | 2px Primary Focus Ring, Input Border `primary500` | Keyboard Focus가 항상 보임 | Focus 순서와 명확한 Label 유지 |
| Pressed | Primary CTA `primary800`, 짧은 시각 피드백 | 중복 Submit 방지 | 상태 Text가 필요한 경우 안내 |
| Selected | `primary50` Background, `primary400` Border, 선택 Icon/Text | 선택 해제 규칙 유지 | `selected` Semantics와 Text 상태 제공 |
| Disabled | `disabledFill`, `textDisabled`, 필요 시 `borderDisabled` | Tap/Click 차단 | 비활성 이유가 중요하면 Helper Text 제공 |
| Loading | 기존 Layout 크기를 유지하며 Progress 또는 Skeleton 표시 | Submit 중 중복 실행 차단 | `liveRegion` 성격의 진행 Label 제공, 무한 반복 장식 금지 |
| Error | `error`, `errorBackground`, Icon과 설명 Text | 재시도 또는 수정 Action 제공 | 색만으로 표현하지 않고 오류 Field와 연결 |

## Component별 State Mapping

### PrimaryButton

| State | Background | Foreground | 추가 처리 |
|---|---|---|---|
| Default | `primary600` | `textInverse` | Height 52, Radius 14 |
| Hover | `primary700` | `textInverse` | 160~220ms |
| Focus | `primary600` | `textInverse` | 2px `primary100` Ring |
| Pressed | `primary800` | `textInverse` | 중복 Tap 방지 |
| Disabled | `disabledFill` | `textDisabled` | Action 없음 |
| Loading | `primary600` 또는 Disabled Visual | `textInverse` | Label 유지 또는 Progress와 의미 Label 제공 |

### SecondaryButton

- Default: White Surface + `borderDefault` + `textPrimary` 또는 Primary Text
- Hover: `surfaceSubtle` 또는 `primary50`, Action 의미에 따라 하나로 고정
- Focus: 2px `primary100` Ring
- Pressed: `primary50`
- Disabled: `surfaceSubtle` + `borderDisabled` + `textDisabled`

### SelectionCard

- Default: Surface + `borderDefault`
- Hover: `borderStrong` + `level1`
- Focus: `primary500` Border + `primary100` Ring
- Selected: `primary50` + `primary400` Border + 선택 Text/Icon
- Disabled: `surfaceSubtle` + `borderDisabled` + `textDisabled`
- Error: `errorBackground` + `error` Border + 오류 설명

### InputField

- Default: Surface + `borderDefault`
- Hover: `borderStrong`
- Focus: `primary500` Border + `primary100` Ring
- Error: `error` Border + 아래 12px Error Text
- Disabled: `surfaceSubtle` + `textDisabled`
- Placeholder만으로 Field 의미를 전달하지 않고 Label을 항상 유지한다.

### Card and GuideTaskCard

- Default: Surface + `borderSubtle` + Shadow 없음
- Hover 가능 Card: `level1`; 클릭 불가능 Card에는 Hover Elevation을 주지 않는다.
- Selected/Completed: Category 또는 Success Tint를 작은 Indicator 영역에만 적용한다.
- Loading: Card 높이를 유지하는 Skeleton 또는 Progress 상태를 사용한다.
- Error: 전체 Card를 강한 Error 색으로 채우지 않고 Error Banner/Inline 상태를 사용한다.

## Motion

- 일반 상태 전환: 160~220ms
- 큰 Layout 전환: 240~300ms
- 반복 Pulse와 Floating Animation 금지
- Reduced Motion 설정에서는 위치/크기 Animation을 제거하거나 즉시 전환한다.

# Flutter Mapping

## Color Token Mapping

| DESIGN.md | Flutter Token | Theme Mapping |
|---|---|---|
| `color.primary.600` | `AppColors.primary600` | `ColorScheme.primary`, Primary Button Default |
| `color.primary.700` | `AppColors.primary700` | Primary Button Hover |
| `color.primary.800` | `AppColors.primary800` | Primary Button Pressed |
| `color.primary.50` | `AppColors.primary50` | `ColorScheme.primaryContainer`, Selected Background |
| 독립 Secondary 없음 | `AppColors.primary600` 재사용 | `ColorScheme.secondary` |
| `color.bg.canvas` | `AppColors.canvas` | `Scaffold.backgroundColor` |
| `color.bg.surface` | `AppColors.surface` | `ColorScheme.surface`, Card/Input |
| `color.bg.surface_subtle` | `AppColors.surfaceSubtle` | `ColorScheme.surfaceContainerLow` 성격 |
| `color.text.primary` | `AppColors.textPrimary` | `ColorScheme.onSurface`, 기본 Text |
| `color.text.secondary` | `AppColors.textSecondary` | 보조 Text |
| `color.text.tertiary` | `AppColors.textTertiary` | Caption, 비선택 Navigation |
| `color.text.inverse` | `AppColors.textInverse` | `ColorScheme.onPrimary` |
| `color.text.disabled` | `AppColors.textDisabled` | Disabled Foreground |
| `color.border.subtle` | `AppColors.borderSubtle` | Card/조건부 Divider |
| `color.border.default` | `AppColors.borderDefault` | `ColorScheme.outline`, Input/Secondary Button |
| `color.border.strong` | `AppColors.borderStrong` | `ColorScheme.outlineVariant` 및 강한 구분 |
| `semantic.success` | `AppColors.success` | 완료 상태 |
| `semantic.warning` | `AppColors.warning` | 주의 상태 |
| `semantic.danger` | `AppColors.error` | `ColorScheme.error` |
| `semantic.info` | `AppColors.info` | 정보 상태 |
| `category.*` | `AppColors.meal/home/body/sleep` | Category Icon/Label/Indicator |

## Typography Mapping

| DESIGN.md | Flutter Token | 적용 |
|---|---|---|
| Display `28/38/700` | `AppTypography.display` | `TextTheme.displaySmall`, Hero |
| Title 1 `24/34/700` | `AppTypography.title1` | `TextTheme.headlineSmall`, Page Title |
| Title 2 `20/29/700` | `AppTypography.title2` | `TextTheme.titleLarge` |
| Heading `18/27/700` | `AppTypography.heading` | `TextTheme.titleMedium`, Section Heading |
| Body 1 `16/25/400` | `AppTypography.body1` | `TextTheme.bodyLarge` |
| Body 2 `14/22/400` | `AppTypography.body2` | `TextTheme.bodyMedium` |
| Label `13/19/600` | `AppTypography.label` | `TextTheme.labelLarge` |
| Caption `12/18/400` | `AppTypography.caption` | `TextTheme.bodySmall` |

## Shape and Spacing Mapping

| DESIGN.md | Flutter Token | 적용 |
|---|---|---|
| Space 4~48 | `AppSpacing.*` | Padding, Gap, SizedBox |
| Input Radius 12 | `AppRadius.input` | `InputDecorationTheme` |
| Card Radius 14~16 | `AppRadius.card` | `CardThemeData` |
| Hero Radius 18~20 | `AppRadius.hero` | HeroStatusCard |
| Modal Radius 20~24 | `AppRadius.modal` | `DialogThemeData` |
| Button Radius 14~16 | `AppRadius.button` | Button Theme |
| Pill | `AppRadius.full` | Chip/Tag만 |
| Elevation 0 | `AppElevation.none` | 일반 Card |
| Elevation 1 | `AppElevation.level1` | Hover/Floating |
| Elevation Modal | `AppElevation.modal` | Dialog Shadow |

## ThemeData Mapping

`AppTheme.light()`가 다음 Material Theme를 중앙에서 조립한다.

- `ColorScheme`
- `TextTheme`
- `Scaffold.backgroundColor`
- `AppBarTheme`
- `FilledButtonThemeData`
- `OutlinedButtonThemeData`
- `TextButtonThemeData`
- `InputDecorationTheme`
- `CardThemeData`
- `DialogThemeData`
- `BottomNavigationBarThemeData` 또는 프로젝트에서 선택한 Navigation Component Theme
- `DividerThemeData`
- `ChipThemeData`
- `ProgressIndicatorThemeData`
- `Focus`와 Mouse Cursor의 공통 상호작용 기준

Theme만으로 표현하기 어려운 SelectionCard, HeroStatusCard, GuideTaskCard 등은 STEP 4의 공통 Component에서 Token을 직접 참조한다.

# Components affected

| Token Group | Components affected | 적용 원칙 |
|---|---|---|
| Primary/Secondary Color | PrimaryButton, SecondaryButton, Navigation, SelectionCard, Link Action | 공통 CTA는 Primary, 2순위 Action은 Neutral Surface 구조 |
| Background/Surface | AppShell, Scaffold, Card, Input, Modal, ChatBubble | Canvas와 White Surface 계층을 구분 |
| Text | 모든 Text, Input, Navigation, Metadata | 역할별 Text Token 사용, 임의 Grey 금지 |
| Border | Card, Input, Button, Modal, Divider | Shadow 대신 기본 구분 수단으로 사용 |
| Semantic Color | InfoBanner, ErrorState, Success Modal, RealtimeAlert, Form Error | Icon + Text와 함께 사용 |
| Category Color | DailyCareSection, GuideTaskCard, CategoryChip | Icon/Label/Indicator/작은 Tint에 제한 |
| Typography | TopAppBar, HeroStatusCard, Section Heading, Card, Form, Chat | 계층별 Style 재사용, 화면별 TextStyle 금지 |
| Spacing | ResponsiveContent, Page, Section, Card, Form, Modal | 4pt Scale과 Semantic Layout Token 사용 |
| Radius | Button, Input, Card, Hero, Modal, Chip | Component 계층별 차이 유지 |
| Elevation | Card Hover, Floating Menu, Modal | 일반 Card Shadow 없음 |
| Icon Size/Style | Navigation, Button, Status, Category, Modal | Line 기본, Filled 선택 상태만 |
| Content Width | Profile, Condition, Home, Guide, Report, Calendar | Form 560, Dashboard 720 Max Width |
| Breakpoint | AppShell, ResponsiveContent, Metric Grid, Sleep Grid | Main Task Single Column, Secondary만 조건부 2 Column |
| UI State | Button, Input, SelectionCard, GuideTaskCard, AsyncContent | Default부터 Error까지 동일한 상태 문법 사용 |

## Core Component별 주요 Token

| Component | 주요 Token |
|---|---|
| `AppShell` | `canvas`, Page Padding, Content Width, Bottom Navigation Height |
| `TopAppBar` | Height 56, `surface`, `borderSubtle`, Detail Title 16/600 |
| `PrimaryButton` | `primary600/700/800`, `disabledFill`, Height 52, Radius 14 |
| `SecondaryButton` | `surface`, `borderDefault`, `textPrimary`, Radius 14 |
| `SelectionCard` | `surface`, `primary50`, `primary400`, Radius 14, Padding 14×16 |
| `InputField` | Height 52, Radius 12, `borderDefault`, Focus/Error Token |
| `InfoCard` | `surface`, `borderSubtle`, Radius 16, Padding 16~20 |
| `HeroStatusCard` | Radius 20, `display`, `primary600`, Category 장식 최소화 |
| `ProgressMetric` | `body/label`, Neutral Track, State Text, Semantic Color 제한 |
| `GuideTaskCard` | Radius 16, Category Icon Tint, Status Text/Icon |
| `ChatBubble` | User Primary, Assistant Neutral Surface, Radius 16 + Corner 6 |
| `Modal` | `surfaceElevated`, Radius 22, `scrim`, Modal Shadow, Primary CTA |
| `ConditionCalendar` | Selected Primary Ring, 상태 Dot/Tint, 항상 보이는 Legend |

# 생성 또는 수정 예정 파일

이번 STEP 3에서는 Flutter 코드를 생성하거나 수정하지 않는다. 아래 목록은 설계 승인 후 Foundation 구현 단계에서 실제로 적용할 파일이다.

## 생성 예정

```text
frontend/lib/design_system/tokens/app_colors.dart
frontend/lib/design_system/tokens/app_typography.dart
frontend/lib/design_system/tokens/app_spacing.dart
frontend/lib/design_system/tokens/app_radius.dart
frontend/lib/design_system/tokens/app_elevation.dart
frontend/lib/design_system/tokens/app_icon_size.dart
frontend/lib/design_system/theme/app_theme.dart
frontend/lib/design_system/theme/app_component_theme.dart
frontend/lib/core/responsive/app_breakpoints.dart
frontend/lib/core/responsive/responsive_content.dart
```

## 수정 예정

```text
frontend/lib/app.dart
```

- 현재 `app.dart`의 `ColorScheme.fromSeed(Colors.indigo)` Inline Theme를 `AppTheme.light()`로 교체한다.
- 기존 `MaterialApp` 구조는 STEP 2의 Routing 적용 시점과 조율하며 Design System만을 이유로 불필요하게 전면 변경하지 않는다.

## 조건부 수정

```text
frontend/pubspec.yaml
```

Pretendard 또는 ThinQ Host Font Asset이 실제로 제공될 때만 Font를 등록한다. 현재는 Font 파일이 없으므로 수정하지 않는다.

## 이번 STEP에서 실제 변경한 문서

```text
docs/development/03_design_system.md
docs/development/frontend_workflow.md
```

