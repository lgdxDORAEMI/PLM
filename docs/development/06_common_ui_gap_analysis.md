# 공통 UI Gap 분석

## 1. 분석 범위와 원칙

- 기준 자료: `docs/screens/**` 24개 이미지, `docs/SCREEN_IMPLEMENTATION_MAP.md`, `DESIGN.md`
- 세 화면 이상에서 의미와 Interaction이 반복되면 Design System 공용 Component로 분류한다.
- 한 Feature 안에서만 반복되면 해당 Feature의 `widgets/`에 둔다.
- 한 화면에서만 필요한 조합은 Screen 내부에서 구성한다.
- 기존 Component의 작은 API 확장으로 해결할 수 있으면 새 Component를 만들지 않는다.
- 이번 작업은 공통 UI 기반만 준비하며 제품 Screen의 상세 UI와 상태 관리는 구현하지 않는다.

## 2. 기존 Component 재사용 판단

| 기존 요소 | 판단 | 적용 범위 |
| --- | --- | --- |
| `AppButton` | 그대로 재사용 | 주요·보조 Action |
| `AppCard` | 그대로 재사용 | 표준 Surface와 Feature Card의 기반 |
| `SelectionCard` | 그대로 재사용 | 프로필, 컨디션, 활동, 식사, 수면 선택 UI |
| `TopAppBar` | 그대로 재사용 | 상세 화면 Header |
| `AppBottomNavigation` | 그대로 재사용 | 역할별 최상위 Navigation |
| `AppInput` | API 확장 | 도움말, 오류, Prefix/Suffix, 입력 유형, 제출 이벤트가 필요한 Form |

`AppInput`은 날짜·단위·메시지 입력을 위한 별도 Input을 미리 만들지 않고, Flutter 기본 Picker나 Feature 조합에서 재사용할 수 있도록 범용 속성만 추가했다.

## 3. 공용 Component로 준비한 항목

| Component | 반복 근거 | 책임 |
| --- | --- | --- |
| `ResponsivePageContent` | 대부분의 Form, Guide, Report 화면 | Mobile/Tablet 여백과 Form·Dashboard 최대 폭 |
| `SectionHeader` | Home, Guide, Report의 Section 제목 | 제목·설명·선택적 보조 Action |
| `InfoBanner` | 초대, Home, 건강, 수면, Partner 상태 | 안내·성공·경고·오류를 Icon과 Text로 전달 |
| `AppBadge` | 카테고리, 완료 상태, 요청·알림 상태 | 의미별 작은 Label. 상태 의미 Mapping은 Feature가 담당 |
| `AppLoadingState` | 비동기 조회·생성 화면 전반 | 접근 가능한 Loading 상태 |
| `AppEmptyState` | Calendar, Report, Notification 등 | 빈 결과와 선택적 복구 Action |
| `AppErrorState` | 비동기 화면 전반 | 오류 설명과 선택적 재시도 Action |
| `GuideTaskCard` | 가사, 건강, Daily/Partner Report | 안내 Task의 제목·설명·상태·Action 골격 |

관련 Token에는 `DESIGN.md`에 이미 정의된 전체 Primary 단계, Semantic 배경색, Category 전경·배경색과 반응형 Breakpoint를 추가했다. 색상과 화면 폭을 Screen에서 하드코딩하지 않기 위한 보완이며 새로운 시각 규칙은 만들지 않았다.

## 4. Feature 내부 Component로 보류한 항목

아래 요소는 반복되더라도 Domain 의미와 상태 전이가 강하므로 실제 해당 Screen 구현 시 각 Feature의 `widgets/`에 추가한다.

| Feature | 후보 Component | 보류 이유 |
| --- | --- | --- |
| `profile` | `ProfileProgress`, `ProfileWizardForm`, `ProfileSummary` | 프로필 단계와 검증 규칙에 종속 |
| `condition` | `ProgressMetric`, `ConditionMetricRow`, `ConditionSelector` | 신체 부위·컨디션 값 의미에 종속 |
| `home` | `PregnancyWeekHero`, `DailyCareSection`, `RoutineGuideCard` | Home 정보 계층과 루틴 상태에 종속 |
| `meal` | `MealPeriodSelector`, `MealRecommendationCard`, `ChatBubble`, `MealRechoiceCard` | 식사 추천 및 Chat 상태에 종속 |
| `household` | `HouseholdTaskGroup`, `HouseholdShareSelector`, `RequestStatusView` | 가족 분담과 요청 상태 전이에 종속 |
| `health` | `BodyLoadSummary`, `HealthActivityCard` | 건강 콘텐츠와 부위별 부담 정보에 종속 |
| `sleep` | `SleepEnvironmentSelector`, `SleepTipList` | 수면 환경 설정과 추천값에 종속 |
| `report` | `ConditionCalendar`, `DailyReportSummary`, `FamilyParticipationSummary` | 날짜별 기록, 공유 권한, 읽기 전용 Variant에 종속 |
| `movement` | `MovementStatusPanel`, `RealtimeAlertCard` | Sensor 연결과 위험 Log 상태에 종속 |
| `partner` | `NotificationListItem`, `PartnerRequestCard`, `InvitationAcceptancePanel` | Partner 전용 알림·요청·초대 흐름에 종속 |

`StatusBadge`, `CategoryBadge`, `ConditionSummaryBanner` 같은 별도 공용 이름은 만들지 않는다. 각각 `AppBadge`, `InfoBanner`에 Feature가 올바른 Label과 Tone을 전달하는 방식으로 해결한다.

## 5. Screen 내부 구현으로 유지할 항목

- 프로필 요약의 초대 진입 Card처럼 한 화면에서만 사용하는 정보 조합
- 이미지의 고유 Hero 조합과 화면별 Intro 문구
- 공유 완료 Dialog의 실제 메시지와 Button 배치
- Calendar 선택일 아래의 화면별 Summary 조합
- 실시간 화면의 단일 동의 안내와 자정 초기화 문구

Dialog, Calendar, Chat 입력창처럼 형태가 비슷해 보여도 실제 요구사항과 상태 전이가 확정되기 전에는 공용 API를 먼저 만들지 않는다.

## 6. 남은 Gap과 구현 시점

- 공통 Dialog는 여러 이미지에 나타나지만 내용·닫기 정책·성공 후 이동 규칙이 아직 다르므로 첫 실제 Flow 구현 때 최소 API를 확정한다.
- Skeleton Loading은 실제 목록·Card 크기가 정해진 뒤 화면 또는 Feature 수준으로 만든다. 현재는 범용 Progress 상태만 제공한다.
- Hover, Focus, Transition은 각 Interactive Component를 실제 Screen에 배치할 때 추가 검증한다.
- `SCREEN_IMPLEMENTATION_MAP.md`의 C-01~C-10 충돌은 이번 작업에서 임의로 해소하지 않았다.
- 모든 제품 Screen의 구현 상태는 계속 `SKELETON`이다.
