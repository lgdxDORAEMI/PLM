# PLM Screen Implementation Map

## 1. 목적과 판정 기준

이 문서는 최신 Requirement, `화면설계서0916.pdf`, 실제 `docs/screens/**` Screen ID, `docs/development/ROUTE_MAP.md`, 현재 Flutter 구현을 연결하는 화면 단위 추적 문서다.

우선순위는 다음과 같다.

1. `docs/requirements/04_1_기능요구사항명세서.md`
2. `docs/requirements/03_유스케이스명세서.md`
3. `docs/requirements/화면설계서0916.pdf`
4. `docs/screens/**`
5. `DESIGN.md`
6. `docs/development/ROUTE_MAP.md`
7. `frontend/lib/**`

PNG는 정보 구조와 콘텐츠 배치 참고자료이며, 최종 시각 규칙은 `DESIGN.md`를 따른다. 현재 코드에 화면이 존재한다는 이유만으로 구현 완료로 판정하지 않는다. Requirement, 화면설계서, Route, Actor Navigation, 상태 전이가 모두 맞아야 `MATCH`다.

### 구현 상태

| 상태 | 의미 |
|---|---|
| `MATCH` | 최신 기능·구조·흐름과 현재 구현이 유지 가능한 수준으로 일치 |
| `STYLE_UPDATE` | 기능·흐름은 유지 가능하고 Design System 중심 시각 보정 필요 |
| `LAYOUT_UPDATE` | 기능은 있으나 정보 구조, 배치, Modal/Sheet 표현 변경 필요 |
| `FLOW_UPDATE` | 화면은 있으나 canonical Route, 이전/다음 화면, Actor Navigation 또는 상태 전이 변경 필요 |
| `REBUILD` | 기존 구현 재사용 범위가 작아 화면/상태 구조를 다시 구성해야 함 |
| `NEW` | 현재 Flutter 구현에 없는 신규 화면 또는 상태 |
| `REMOVE_OR_DISABLE` | 현재 구현은 있으나 최신 범위에서 제거하거나 비활성화해야 함 |
| `PHASE_2` | 최신 요구사항에서 Phase 2로 명시된 범위 |

## 2. 화면설계서 페이지 인덱스

`화면설계서0916.pdf`는 기능 순서로 정렬되어 있지 않으므로 실제 페이지를 기준으로 참조한다.

| 페이지 | Screen ID / 내용 |
|---|---|
| 1 | `W-PROFILE-005` |
| 2 | `B-MOTION-001` |
| 3 | `B-ENTRY-001` 및 두 Entry variant |
| 4 | `B-CAL-001` Wife/Partner 공통 구조 |
| 5 | `W-INVITE-001` |
| 6 | `W-SLEEP-001` |
| 7 | `W-REPORT-001`, 공유 완료 popup inset |
| 8~9 | `W-PROFILE-007`, 최초 등록/수정 Summary variant |
| 10 | `W-PROFILE-006` |
| 11 | `W-CHAT-001` |
| 12 | `W-HEALTH-001` |
| 13 | `W-HOME-001` 컨디션 입력 전 |
| 14 | `W-COND-001` |
| 15 | `W-TASK-001` |
| 16 | `W-HOME-001` 루틴 생성 후 |
| 17 | `W-SLEEP-001-1` 환경 설정 Bottom Sheet 공통 구조 |
| 18 | `W-CALLBACK-001` |
| 19 | `W-MENU-001` 연동 전/후 |
| 20 | `W-HOUSE-001`, 공유 완료·진행 상태 inset |
| 21 | `H-NOTI-001` |
| 22 | `H-REPORT-001` |
| 23~25 | `H-REQUEST-001` 확인/진행/완료 상태 |
| 26 | `W-REPORT-001-1` 보조 표기 페이지 |
| 27 | 내용 없음 |
| 28 | `W-MEAL-001` |
| 29 | `W-MEAL-002` |
| 30 | `W-MEAL-003` |
| 31~34 | `W-PROFILE-001`~`W-PROFILE-004` |

## 3. Screen ID별 구현 매핑

### 3.1 Entry, Profile, Invite, Menu

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `B-ENTRY-001` | `FUC-B-ENTRY-001` | Both | `docs/screens/B-ENTRY-001.png` | p.3, ThinQ 홈 배너 | `/entry` | `entry`, `routing` | 전용 파일 없음; `frontend/lib/app.dart`, `frontend/lib/routing/app_router.dart` | Host banner entry | 신규 Host banner/Bootstrap shell | `EntryResolver`, session/role adapter 필요 | loading, role unknown, resolved, recoverable error | 배너 선택 → 역할·Profile·연동 상태 분기 | MVP | `NEW` |
| `B-ENTRY-001-1` | `FUC-B-ENTRY-001` | Both | `docs/screens/B-ENTRY-001-1.png` | p.3, ThinQ 메뉴 Entry | `/entry` 내부 host state | `entry`, `routing` | 전용 파일 없음 | Host menu entry | 신규 Host menu row | `EntryResolver` 공유 | 노출/미노출, NEW badge | 메뉴 선택 → 동일 Bootstrap 분기 | MVP | `NEW` |
| `W-PROFILE-001` | `FUC-W-PROFILE-001` | Wife | `docs/screens/W-PROFILE-001.png` | p.31 | `/onboarding/profile`, `/wife/profile` 내부 step 1 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | 6-step form, date picker | `TopAppBar`, `AppButton`, form layout | `ProfileWizardFrame`, `ProfileDateField`, `ProfileProgress` | empty, valid, validation error | 출산예정일 또는 LMP 선택 → step 2 | MVP | `MATCH` |
| `W-PROFILE-002` | `FUC-W-PROFILE-002` | Wife | `docs/screens/W-PROFILE-002.png` | p.32 | 동일 Profile Route 내부 step 2 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | numeric form | `TopAppBar`, `AppInput`, `AppButton` | `_BodyFields`, `ProfileUnitInput` | empty, valid, range error | 임신 전 신장·체중 입력 → step 3 | MVP | `REBUILD` |
| `W-PROFILE-003` | `FUC-W-PROFILE-003` | Wife | `docs/screens/W-PROFILE-003.png` | p.33 | 동일 Profile Route 내부 step 3 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | single-select cards | `SelectionCard`, `AppButton` | `ProfileWizardFrame` | unselected, selected | 초산/경산 선택; 미선택 시 다음 비활성 | MVP | `MATCH` |
| `W-PROFILE-004` | `FUC-W-PROFILE-004` | Wife | `docs/screens/W-PROFILE-004.png` | p.34 | 동일 Profile Route 내부 step 4 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | single-select cards | `SelectionCard`, `AppButton` | `ProfileWizardFrame` | unselected, selected | 단태/다태 선택; 미선택 시 다음 비활성 | MVP | `MATCH` |
| `W-PROFILE-005` | `FUC-W-PROFILE-005` | Wife | `docs/screens/W-PROFILE-005.png` | p.1 | 동일 Profile Route 내부 step 5 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | multi-select chip grid | `SelectionCard`, `AppButton` | `ProfileChoiceGrid` | none/later, multi-selected, 없음 | 알레르기 복수 선택; 없음은 다른 선택 해제 | MVP | `MATCH` |
| `W-PROFILE-006` | `FUC-W-PROFILE-006` | Wife | `docs/screens/W-PROFILE-006.png` | p.10 | 동일 Profile Route 내부 step 6 | `profile` | `frontend/lib/features/profile/screens/profile_setup_screen.dart` | multi-select + free text | `AppInput`, `AppButton` | `ProfileChoiceGrid`, `ProfileWizardFrame` | optional empty, selected, note entered | 진단 복수 선택·자유 입력 → Summary | MVP | `MATCH` |
| `W-PROFILE-007` | `FUC-W-PROFILE-007`, `FUC-W-PROFILE-008` | Wife | `docs/screens/W-PROFILE-007.png` | pp.8~9 | Profile Route 내부 Summary state | `profile` | `frontend/lib/features/profile/widgets/profile_summary.dart`, `controllers/profile_setup_controller.dart` | editable summary list | `InfoBanner`, `AppCard`, `AppButton` | `ProfileSummary`, `_SummaryItem` | complete/incomplete, create/edit | 행 선택 → 해당 step; 해당 step 저장 → Summary; 최종 저장 → Invite 또는 Menu | MVP | `FLOW_UPDATE` |
| `W-INVITE-001` | `FUC-W-INVITE-001`, `FUC-W-INVITE-002` | Wife | `docs/screens/W-INVITE-001.png` | p.5 | `/onboarding/invite`, `/wife/invite` | `profile`, `invitation` | `frontend/lib/features/profile/screens/partner_invite_screen.dart`; `features/invitation/**` | benefit cards + invite link/action | `TopAppBar`, `AppCard`, `AppButton`, state views | `PartnerInviteController`, `InvitationService` | idle, generating, ready, sharing, error | 링크 생성·복사·OS 공유; 온보딩은 Home, Menu 진입은 Menu 복귀 | MVP | `FLOW_UPDATE` |
| `W-MENU-001` | `FUC-W-MENU-001` | Wife | `docs/screens/W-MENU-001.png` | p.19, 연동 전 | `/wife/menu` | `menu`, `profile` | 전용 화면 없음; `wife_home_screen.dart`와 `product_skeleton_screen.dart`의 popup만 존재 | full-page menu/list | `TopAppBar`, `AppCard`, `InfoBanner` | `ProfileHeader`, `MenuRow`, `PartnerLinkRow` 필요 | partner unlinked | 프로필 수정·초대·설정 진입, 뒤로 returnLocation | MVP | `NEW` |
| `W-MENU-001-1` | `FUC-W-MENU-001` | Wife | `docs/screens/W-MENU-001-1.png` | p.19, 연동 후 | `/wife/menu` 내부 linked state | `menu`, `profile` | 전용 파일 없음 | conditional menu state | `InfoBanner`, `AppBadge` | `PartnerLinkRow` 필요 | partner linked | 초대 Action 제거, 연동됨 안내 표시 | MVP | `NEW` |

`W-PROFILE-002`의 현재 구현에는 최신 Requirement에 없는 나이 입력과 필수 검증이 포함되어 있어 재구성이 필요하다. `W-PROFILE-007`은 Summary 행에서 편집한 뒤 곧바로 Summary로 돌아와야 하지만 현재 Controller는 다음 step으로 순차 진행한다.

### 3.2 Wife Home, Condition, Activity, Callback

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `W-HOME-001` | `FUC-W-HOME-001` | Wife | `docs/screens/W-HOME-001.png` | p.13 | `/wife/home` | `home`, `routine` | `frontend/lib/features/home/screens/wife_home_screen.dart`; `features/routine/**` | welcome + week guide + conditional CTA | `TopAppBar`, `InfoBanner`, `AppButton`, `AppBottomNavigation` | `PregnancyWeekHero`, `PregnancyWeekTipCard`, `DailyRoutineController` | condition missing | 컨디션 CTA → `/wife/condition`; Header profile → `/wife/menu` | MVP | `FLOW_UPDATE` |
| `W-HOME-001-1` | `FUC-W-HOME-001`, `FUC-W-HOME-002` | Wife | `docs/screens/W-HOME-001-1.png` | p.16 | `/wife/home` 내부 ready state | `home`, `routine` | 동일 | scrollable 4-guide dashboard | `SectionHeader`, `AppButton`, `AppBottomNavigation` | `RoutineGuideCard`, `DailyRoutinePlan` | loading, ready, fallback, last-updated | 4종 Guide 진입; 일정 마치기 → `/wife/report/{actualDate}` | MVP | `FLOW_UPDATE` |
| `W-COND-001` | `FUC-W-COND-001`, `FUC-W-COND-002` | Wife | `docs/screens/W-COND-001.png` | p.14 | `/wife/condition?mode=create\|edit` | `condition` | `frontend/lib/features/condition/screens/condition_screen.dart`; `controllers/today_care_controller.dart` | segmented condition form | `TopAppBar`, `AppButton`, state feedback | `ConditionMetric`, `PainMetricCard`, `TodayCareStore` | create/edit, dirty, saving, error | 1일 1건 upsert; 저장 → `/wife/activity`; report trigger 실패는 저장 성공 유지 | MVP | `FLOW_UPDATE` |
| `W-TASK-001` | `FUC-W-TASK-001` | Wife | `docs/screens/W-TASK-001.png` | p.15 | `/wife/activity` | `condition` | `frontend/lib/features/condition/screens/activity_screen.dart`; `planned_activity_controller.dart` | 3×3 multi-select grid + custom input | `TopAppBar`, `AppInput`, `AppButton` | `_ActivityCard`, `PlannedActivityStore` | none/multi-selected, custom items, generating | 선택·직접 추가 → AI Routine 요청 → `/wife/home` | MVP | `FLOW_UPDATE` |
| `W-CALLBACK-001` | `FUC-W-CALLBACK-001` | Wife | `docs/screens/W-CALLBACK-001.png` | p.18 | 별도 Route 없음; AI 호출 Route 내부 state | `routine`, `meal`, `health`, `sleep`, `chat` | `frontend/lib/features/routine/controllers/daily_routine_controller.dart`; `mock_routine_service.dart` | inline loading/error/fallback pattern | `AppLoadingState`, `AppErrorState`, `InfoBanner` | 공통 `AiFallbackView` 필요 | timeout, error, retrying, fallback-ready | 재시도 또는 전일 루틴/기본 템플릿 유지; 화면 이동 없음 | MVP | `LAYOUT_UPDATE` |

### 3.3 Meal, Chat, Household, Health, Sleep

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `W-MEAL-001` | `FUC-W-MEAL-001` | Wife | `docs/screens/W-MEAL-001.png` | p.28 | `/wife/meal` 내부 meal-selection state | `meal` | `frontend/lib/features/meal/screens/meal_guide_screen.dart` | meal-period selector/list | `TopAppBar`, `AppCard`, `AppBadge`, `AppBottomNavigation` | `MealPeriodCard`, `MealGuideController` | loading, ready, error, current period | 현재 끼니 강조; 다른 끼니 선택 → 상세 갱신 | MVP | `FLOW_UPDATE` |
| `W-MEAL-002` | `FUC-W-MEAL-002`, `FUC-W-MEAL-004`, `FUC-W-MEAL-005` | Wife | `docs/screens/W-MEAL-002.png` | p.29 | `/wife/meal` 내부 detail state | `meal` | `frontend/lib/features/meal/screens/meal_guide_screen.dart`; `widgets/meal_recommendation_card.dart` | recommendation detail + evidence/caution | `InfoBanner`, `AppCard`, `AppBadge` | `MealRecommendationCard`, `MealInfoSection`, `MealSelectionStore` | recommendation, accepted/rejected, sharing, fallback | 재조정 바 → `/wife/chat`; 수락/거절 이력; Partner 공유 | MVP | `FLOW_UPDATE` |
| `W-MEAL-003` | `FUC-W-MEAL-003` | Wife | `docs/screens/W-MEAL-003.png` | p.30 | `/wife/chat` 내부 `source=meal` context | `meal`, `chat` | `frontend/lib/features/meal/screens/meal_chat_screen.dart` | contextual chat + recommendation card | `TopAppBar`, `AppInput`, `AppButton`, `AppBottomNavigation` | `MealChatBubble`, `MealRecommendationCard`, `MealChatController` | composing, waiting, result, retry/error | 이걸로 할게요 → Meal 교체; 다른 메뉴 보기 → 재추천 | MVP | `FLOW_UPDATE` |
| `W-CHAT-001` | `FUC-W-CHAT-001`; `FUC-W-CHAT-002`는 Phase 2 | Wife | `docs/screens/W-CHAT-001.png` | p.11 | `/wife/chat` | `chat`, `meal` | `frontend/lib/features/meal/screens/meal_chat_screen.dart` | persistent-context conversational screen | `TopAppBar`, `AppInput`, `AppButton`, `AppBottomNavigation` | `MealChatBubble`, `_MealChatContext`, `_SuggestedPrompts` | idle, responding, error, applied | 식사 재조정만 허용; 가사·건강·수면 재조정은 비활성 | MVP / 전체 루틴 Chat Phase 2 | `FLOW_UPDATE` |
| `W-HOUSE-001` | `FUC-W-HOUSE-001`~`003` | Wife | `docs/screens/W-HOUSE-001.png` | p.20, main | `/wife/household` | `household` | `frontend/lib/features/household/screens/household_guide_screen.dart` | 3-section task groups + share selector | `TopAppBar`, `AppCard`, `AppButton`, `AppBottomNavigation` | `HouseholdTaskCard`, `HouseholdGuideController` | planned, selected, sharing | 직접/가전/가족 분담 확인; Partner 공유 | MVP; 실제 가전 실행 Phase 2 | `FLOW_UPDATE` |
| `W-HOUSE-001-1` | `FUC-W-HOUSE-003-1` | Wife | `docs/screens/W-HOUSE-001-1.png` | p.20, 6-1 inset | `/wife/household` 내부 Modal | `household` | `frontend/lib/features/household/screens/household_guide_screen.dart` | dimmed result dialog | `AlertDialog`, `AppButton` | 공유 결과 Dialog | success, resend/error | 확인 → Modal 닫기; 요청 카드 진행 상태 반영 | MVP | `STYLE_UPDATE` |
| `W-HOUSE-001-2` | `FUC-W-HOUSE-003` | Wife | `docs/screens/W-HOUSE-001-2.png` | p.20, 6-2 inset | `/wife/household` 내부 content state | `household` | 동일 | status-aware task cards | `AppBadge`, `InfoBanner` | `HouseholdTaskCard`, `_LiveStatusBanner` | shared, confirmed, done | 상태 갱신·가족 분담 기록 표시 | MVP | `MATCH` |
| `W-HEALTH-001` | `FUC-W-HEALTH-001`, `FUC-W-HEALTH-002` | Wife | `docs/screens/W-HEALTH-001.png` | p.12 | `/wife/health` | `health` | `frontend/lib/features/health/screens/health_guide_screen.dart`; `widgets/movement_guide_card.dart` | priority body-load + activity cards | `TopAppBar`, `AppCard`, `InfoBanner`, `AppBottomNavigation` | `_BodySummary`, `_BodyLoadCard`, `MovementGuideCard`, `BodyCareController` | loading, ready, selected body part, completed, fallback | 대표/보조 활동 조회·완료 체크; 기록 반영 | MVP; Motion 기반 고도화 Phase 2 | `FLOW_UPDATE` |
| `W-SLEEP-001` | `FUC-W-SLEEP-001`, `FUC-W-SLEEP-002` | Wife | `docs/screens/W-SLEEP-001.png` | p.6 | `/wife/sleep` | `sleep` | `frontend/lib/features/sleep/screens/sleep_guide_screen.dart` | evidence banner + 5 environment tiles + tips | `TopAppBar`, `AppCard`, `AppButton`, `AppBottomNavigation` | `SleepEnvironmentCard`, `SleepGuideController` | loading, ready, error, settings changed | 각 타일 → 개별 Sheet; 전체 수면 루틴 실행은 Phase 2 | Main MVP / 실행 Phase 2 | `REBUILD` |
| `W-SLEEP-001-1` | `FUC-W-SLEEP-001-1` | Wife | `docs/screens/W-SLEEP-001-1.png` | p.17, 조명 variant | `/wife/sleep` 내부 Bottom Sheet | `sleep` | `frontend/lib/features/sleep/screens/sleep_guide_screen.dart` | single-setting option sheet | Modal Bottom Sheet, `AppButton` | 전용 `SleepSettingSheet` 필요 | recommended selected, changed | 조명 선택·적용 | MVP UI; 실제 가전 적용 Phase 2 | `REBUILD` |
| `W-SLEEP-001-2` | `FUC-W-SLEEP-001-1` | Wife | `docs/screens/W-SLEEP-001-2.png` | p.17 공통 구조, 온도 variant | 동일 | `sleep` | 동일 | single-setting input/option sheet | Modal Bottom Sheet, `AppInput`, `AppButton` | `SleepSettingSheet.temperature` 필요 | recommended, direct input, range error | 0~40°C 검증·적용 | MVP UI; 실제 가전 적용 Phase 2 | `REBUILD` |
| `W-SLEEP-001-3` | `FUC-W-SLEEP-001-1` | Wife | `docs/screens/W-SLEEP-001-3.png` | p.17 공통 구조, 습도 variant | 동일 | `sleep` | 동일 | single-setting input/option sheet | Modal Bottom Sheet, `AppInput`, `AppButton` | `SleepSettingSheet.humidity` 필요 | recommended, direct input, range error | 0~100% 검증·적용 | MVP UI; 실제 가전 적용 Phase 2 | `REBUILD` |
| `W-SLEEP-001-4` | `FUC-W-SLEEP-001-1` | Wife | `docs/screens/W-SLEEP-001-4.png` | p.17 공통 구조, 소리 variant | 동일 | `sleep` | 동일 | single-setting option sheet | Modal Bottom Sheet, `AppButton` | `SleepSettingSheet.sound` 필요 | recommended, selected | 소리 선택·적용 | MVP UI; 실제 가전 적용 Phase 2 | `REBUILD` |
| `W-SLEEP-001-5` | `FUC-W-SLEEP-001-1` | Wife | `docs/screens/W-SLEEP-001-5.png` | p.17 공통 구조, 공기청정기 variant | 동일 | `sleep` | 동일 | single-setting option sheet | Modal Bottom Sheet, `AppButton` | `SleepSettingSheet.airPurifier` 필요 | recommended, selected | 운전 모드 선택·적용 | MVP UI; 실제 가전 적용 Phase 2 | `REBUILD` |

현재 Sleep 구현은 다섯 설정을 한 Sheet의 Dropdown으로 동시에 편집하고 별도 “설정 직접 변경하기” 버튼을 사용한다. 최신 계약은 각 환경 타일을 탭해 항목별 Bottom Sheet를 여는 구조이므로 Main과 Sheet를 함께 재구성해야 한다.

### 3.4 Report, Calendar, Motion

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `W-REPORT-001` | `FUC-W-REPORT-001`; `FUC-W-REPORT-002`는 Phase 2 | Wife | `docs/screens/W-REPORT-001.png` | p.7 | `/wife/report/:date` | `report` | `frontend/lib/features/report/screens/daily_report_screen.dart` | metrics + routine list + family summary | `TopAppBar`, `AppCard`, `AppButton`, `AppBottomNavigation`, state views | `ReportMetricCard`, `RoutineRecordCard`, `DailyReportController` | loading, empty, error, saving, sharing | 실제 date 조회; 저장 → Calendar + Home 초기화; 공유 → Modal | MVP / Motion 통계 Phase 2 | `FLOW_UPDATE` |
| `W-REPORT-001-1` | `FUC-W-REPORT-001-1` | Wife | `docs/screens/W-REPORT-001-1.png` | p.7 inset, p.26 보조 표기 | `/wife/report/:date` 내부 Modal | `report` | `frontend/lib/features/report/screens/daily_report_screen.dart` | dimmed completion dialog | `AlertDialog`, `AppButton` | 공유 결과 Dialog | success, retry/error | 확인 → Report 유지; 저장하고 마치기 → Calendar | MVP | `STYLE_UPDATE` |
| `B-CAL-001` | `FUC-B-CAL-001` | Wife | `docs/screens/B-CAL-001.png` | p.4, Wife variant | `/wife/calendar` | `calendar`, `report` | `frontend/lib/features/calendar/screens/wife_calendar_screen.dart`; `record_calendar_screen.dart` | month calendar + selected-day summary | `TopAppBar`, `AppCard`, `AppBottomNavigation`, state views | `ConditionCalendar`, `ConditionLegend`, `RecordDaySummary`, `RecordCalendarController` | loading, error, selected date, no record, future disabled | 월 이동·날짜 선택·리포트 → `/wife/report/:date` | MVP | `FLOW_UPDATE` |
| `B-CAL-001` | `FUC-B-CAL-001` | Partner | `docs/screens/B-CAL-001.png` | p.4, Partner-only actions 6~7 | `/partner/calendar` | `calendar`, `partner` | `frontend/lib/features/partner/screens/partner_calendar_screen.dart`; `calendar/screens/record_calendar_screen.dart` | Partner root calendar, no bottom navigation | `TopAppBar`, `AppCard`, state views | Calendar 공통 컴포넌트 + notification/movement actions | loading, error, selected date, unread notification | 알림 → Notifications; 리포트; Motion CTA; Bottom Nav/Profile 없음 | MVP; Motion CTA 대상 Phase 2 | `REBUILD` |
| `B-MOTION-001` | `FUC-B-MOTION-001` | Wife | `docs/screens/B-MOTION-001.png` | p.2 | `/wife/movement` | `movement` | `frontend/lib/features/movement/product_movement_screen.dart`; `controllers/realtime_alert_controller.dart` | detection toggle + progress + alert log | `TopAppBar`, `AppCard`, `AppBottomNavigation`, `InfoBanner` | `MovementAlertCard`, `RealtimeAlertController` | off/on, empty, warning, severe, acknowledged | Wife Realtime tab; 가전으로 옮기기 → Household | Phase 2 | `PHASE_2` |
| `B-MOTION-001` | `FUC-B-MOTION-001` | Partner | `docs/screens/B-MOTION-001.png` | p.2 | `/partner/movement` | `movement`, `partner` | `frontend/lib/features/movement/product_movement_screen.dart`; `product_skeleton_screen.dart` | same shared log, no bottom navigation | `TopAppBar`, `AppCard`, `InfoBanner` | `MovementAlertCard`, `RealtimeAlertController` | shared read state | Partner Calendar CTA에서만 진입·뒤로 Calendar | Phase 2 | `PHASE_2` |

### 3.5 Partner Report, Notification, Request

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `H-REPORT-001` | `FUC-H-REPORT-001` | Partner | `docs/screens/H-REPORT-001.png` | p.22 | `/partner/report/:date` | `partner`, `report` | `frontend/lib/features/partner/screens/partner_morning_report_screen.dart` | read-only morning summary | `TopAppBar`, `AppCard`, state views | `_PartnerReportContent`, `_GuideSummary`, `DailyReportController` 재사용 | loading, empty, error, ready | Calendar/리포트 알림에서 실제 date로 진입; 뒤로 원 진입점 | MVP | `FLOW_UPDATE` |
| `H-NOTI-001` | `FUC-H-NOTI-001` | Partner | `docs/screens/H-NOTI-001.png` | p.21 | `/partner/notifications` | `partner`, `notification` | `frontend/lib/features/partner/screens/partner_notifications_screen.dart` | chronological inbox list | `TopAppBar`, `AppCard`, `AppBadge`, empty state | `_NotificationCard`, `PartnerNotificationController` | unread/read, empty, loading/error 필요 | 리포트 알림 → date Report; 요청 알림 → 실제 requestId | MVP; push infrastructure Phase 2 | `FLOW_UPDATE` |
| `H-REQUEST-001` | `FUC-H-REQUEST-001`, `FUC-H-REQUEST-002` | Partner | `docs/screens/H-REQUEST-001.png` | p.24 | `/partner/requests/:requestId` | `partner`, `household` | `frontend/lib/features/partner/screens/partner_request_screen.dart` | requester/reason + per-task cards | `TopAppBar`, `AppCard`, `AppButton`, `AppBadge` | `PartnerRequestController`, `PartnerRequestStore`, `_StatusBadge` | requested, confirmed, completed, not-found/forbidden 필요 | 실제 requestId 조회; 카드별 확인·완료 | MVP | `FLOW_UPDATE` |
| `H-REQUEST-001-1` | `FUC-H-REQUEST-002` | Partner | `docs/screens/H-REQUEST-001-1.png` | p.23, 3-1 inset | 동일 Request Route 내부 Modal | `partner`, `household` | `frontend/lib/features/partner/screens/partner_request_screen.dart` | completion confirmation dialog | `AlertDialog`, `AppButton` | 완료 확인 Dialog | confirm/cancel | 아직이에요 → confirmed 유지; 완료했어요 → 완료 처리 | MVP | `LAYOUT_UPDATE` |
| `H-REQUEST-001-2` | `FUC-H-REQUEST-002` | Partner | `docs/screens/H-REQUEST-001-2.png` | p.23, main | 동일 Request Route 내부 content state | `partner`, `household` | 동일 | per-card progress/status | `AppBadge`, `InfoBanner` | request task state card | mixed requested/confirmed/completed | 카드별 상태 전이, 미완료 요청 유지 | MVP | `FLOW_UPDATE` |
| `H-REQUEST-002` | `FUC-H-REQUEST-003` | Partner | `docs/screens/H-REQUEST-002.png` | p.25 | 동일 Request Route 내부 completion state | `partner`, `household` | `frontend/lib/features/partner/screens/partner_request_screen.dart` | full completion result overlay/content | `AppCard`, `AppButton`, `InfoBanner` | `RequestCompletionView` 필요 | completed result | 반영 위치·가족 분담 요약; Calendar로 돌아가기 | MVP | `LAYOUT_UPDATE` |

Partner 화면의 현재 `PartnerBottomNavigation`, `/partner/profile`, `demo-request`, `today` 별칭은 최신 계약과 충돌한다. Report·Notification·Request 화면에서 Partner Bottom Navigation을 제거하고 Calendar/Notification 기반 흐름으로 통일해야 한다.

## 4. PNG가 없는 Requirement 화면

| Screen ID | Requirement ID | Actor | Screen image | 화면설계서 참조 | Route | Flutter Feature | 현재 Flutter 파일 | UI Pattern | 공통 컴포넌트 | Feature 컴포넌트 | State | Interaction | MVP / Phase2 | 구현 상태 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 없음 | `FUC-W-SETTING-001` | Wife | 없음 | 전용 페이지 없음; p.19 Menu의 설정 행만 참조 | `/wife/settings` | `settings` | `frontend/lib/features/settings/screens/wife_settings_screen.dart` | placeholder page | `TopAppBar`, `AppCard` | 상세 컴포넌트 정의 금지 | development placeholder | Menu에서 진입·뒤로 Menu; 임의 설정 항목 추가 금지 | Phase 2 placeholder | `PHASE_2` |
| 없음 | `FUC-H-INVITE-001` | Partner | 없음 | 전용 페이지 없음 | `/partner/join?token=...` | `partner`, `invitation` | `frontend/lib/features/partner/screens/invitation_entry_screen.dart`; `features/invitation/controllers/invitation_entry_controller.dart` | development placeholder only | `TopAppBar`, `InfoBanner` | 기존 Join workflow 비활성화 필요 | token missing/valid/expired 안내, development placeholder | token 확인 후 “개발중입니다”만 표시; 실제 수락·연동 금지 | MVP Entry only | `REMOVE_OR_DISABLE` |

## 5. 최신 범위에서 제거하거나 비활성화할 구현

| 대상 | 현재 위치 | 판단 | 필요한 처리 |
|---|---|---|---|
| Partner Profile 화면/Route | `frontend/lib/routing/route_names.dart`, `app_router.dart`, `record_calendar_screen.dart` | 최신 Requirement에 Partner Profile이 없고 Partner Header는 Notification 전용 | `/partner/profile`과 Profile Action 제거 |
| Partner Bottom Navigation | `frontend/lib/features/partner/widgets/partner_bottom_navigation.dart`, Partner screens | Partner는 Bottom Navigation을 사용하지 않음 | 화면 부착과 컴포넌트 사용 제거; Calendar를 안전한 기준 화면으로 사용 |
| 실제 Join mock workflow | `invitation_entry_screen.dart`, `invitation_entry_controller.dart` | MVP는 진입점과 개발 중 안내만 허용 | token 상태 표시는 유지 가능하나 설치/로그인/수락/연동 Action 비활성화 |
| Movement debug 초기 진입 | `frontend/lib/app.dart`, `features/movement/movement_debug_screen.dart` | 제품 Bootstrap은 `/entry`; debug 화면은 제품 Route가 아님 | 기본 initial route에서 제거하고 개발용 진입으로 격리 |
| `today`, `demo-request` 경로 | `frontend/lib/routing/route_names.dart`, Partner/Report 화면 | 실제 `YYYY-MM-DD`, 실제 `requestId`만 허용 | 별칭과 고정 데모 ID 제거 |

## 6. 공통 컴포넌트 영향

| 영역 | 유지 가능한 공통 컴포넌트 | 보완/신규 필요 |
|---|---|---|
| Layout/Navigation | `TopAppBar`, `ResponsivePageContent`, `AppBottomNavigation` | Wife 전용 Shell, Partner no-bottom-nav shell, `/entry` Bootstrap shell |
| Action/Form | `AppButton`, `AppInput`, `SelectionCard` | Profile step 저장/요약 복귀 mode, 범위 입력 공통 검증 |
| Card/Status | `AppCard`, `InfoBanner`, `AppBadge`, `GuideTaskCard` | 연결 상태 Menu row, request completion view |
| Async | `AppLoadingState`, `AppEmptyState`, `AppErrorState` | AI 공통 fallback view, parameter Not Found/Forbidden state |
| Overlay | 기본 `AlertDialog`, `showModalBottomSheet` | Design System 기반 공통 result dialog, 항목별 `SleepSettingSheet` |

## 7. 구현 우선순위

1. `NEW`: `/entry`, Wife Menu와 연동 전/후 상태.
2. `REMOVE_OR_DISABLE`: Partner Profile/Bottom Navigation, 실제 Join mock Action, debug initial route, demo aliases.
3. `FLOW_UPDATE`: canonical Route 전환, Profile Summary 복귀, Wife/Partner Navigation, 실제 date/requestId 전달.
4. `REBUILD`: Profile step 2, Sleep Main과 다섯 개 설정 Sheet, Partner Calendar shell.
5. `LAYOUT_UPDATE`·`STYLE_UPDATE`: AI fallback, 공유/완료 Modal과 Request 완료 결과.
6. `PHASE_2`: Motion과 실제 가전 제어·push·전체 루틴 Chat을 MVP 동작에서 분리.
