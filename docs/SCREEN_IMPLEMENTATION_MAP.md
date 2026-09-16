# PLM Screen Implementation Map

## 1. 문서 목적

이 문서는 Flutter 제품 화면을 Task 단위로 구현하고 구현 상태를 추적하기 위한 화면-이미지-Route-Component 연결 문서다.

## 2. Source of Truth

| 영역 | Source of Truth | 적용 범위 |
| --- | --- | --- |
| 화면 구조와 시각 참고 | `docs/screens/**` | 화면의 정보 구조, 콘텐츠, 주요 배치, 상태별 참고 이미지 |
| 디자인 시스템 | `DESIGN.md` | Color, Typography, Spacing, Radius, Component, Interaction state, Responsive, Accessibility |
| 화면 이동 | `docs/development/ROUTE_MAP.md` | 내부 Route, 이전/다음 화면, Parameter, 역할별 Navigation |
| 요구사항 추적 | `docs/requirements/04_1_기능요구사항명세서.md` | `W-*`·`H-*` 기능 요구사항 ID |

> 요청에 명시된 `ROUTEMAP.md`라는 파일은 현재 저장소에 없다. 본 문서는 실제 존재하는 `docs/development/ROUTE_MAP.md`를 Route Source of Truth로 사용한다. 파일명 또는 위치를 별도로 통일할지는 확인이 필요하다.

### Screen ID 표기 규칙

현재 요구사항에는 별도 Screen ID 체계가 없다. 따라서 이 문서의 **Screen ID**는 화면을 대표하는 기능 요구사항 ID를 사용하며, 한 화면이 여러 요구사항을 담당하면 `비고`에 전체 관련 ID를 기록한다. 별도의 화면 전용 ID는 만들지 않는다.

### 구현 상태

- `SKELETON`: Route와 화면 클래스만 있고 실제 제품 UI가 없음
- `IN_PROGRESS`: 실제 UI 구현 중
- `IMPLEMENTED`: 요구 UI와 Interaction 구현 완료
- `VERIFIED`: 분석·테스트·시각 QA·접근성 검증 완료

현재 Profile, Today Care, Home, Meal, Household, Movement, Health, Sleep, Chat, Daily Report와 아내·파트너 공통 Calendar는 `IMPLEMENTED`이며, 나머지 8개 제품 화면은 `SKELETON`이다.

## 3. Source 충돌 및 확인 필요 항목

아래 항목은 구현자가 임의로 결정하지 않는다.

| ID | 충돌 내용 | 관련 화면 | 구현 전 확인 사항 |
| --- | --- | --- | --- |
| C-01 | PNG는 흰색 전체 배경과 강한 pink/purple CTA를 사용하지만 `DESIGN.md`는 warm canvas, white surface, `primary.600` CTA를 요구한다. | 전체 | PNG의 배치·콘텐츠를 유지하면서 DESIGN token을 적용할지 확인 |
| C-02 | PNG의 다수 버튼이 pill 형태지만 `DESIGN.md`는 일반 버튼 radius 14~16, chip만 pill을 요구한다. | 프로필, 초대, 수면, 리포트, 채팅 | Button shape는 DESIGN 규칙 적용 여부 확인 |
| C-03 | PNG는 카테고리별 pastel 면적이 크지만 `DESIGN.md`는 white card와 작은 tint/icon 사용을 요구한다. | 홈, 식사, 가사, 건강, 수면 | Category 배경 면적 축소 여부 확인 |
| C-04 | 공유 완료 Modal의 CTA가 purple이지만 `DESIGN.md`는 product primary color로 통일하도록 명시한다. | 가사, Daily 리포트 | Modal CTA 색상 확인 |
| C-05 | `12_chat.png`는 식사 외 건강 질문과 가사 이동 제안까지 포함하지만 MVP/Route 계약은 식사 재조정 Chat으로 제한한다. | W-CHAT-001 | 일반 Chat 확장 여부가 확정될 때까지 식사 범위만 구현할지 확인 |
| C-06 | 가사·수면 PNG에는 실제 ThinQ 가전 실행 Action이 있으나 MVP는 실제 기기 제어를 제외한다. | W-HOUSE-001, W-SLEEP-001 | 사용자 지시에 따라 추천·선택·Mock 완료 상태만 구현 |
| C-07 | Daily 리포트 PNG에는 가전 자동 실행과 관절 부담 데이터가 있으나 MVP에서 제외되거나 Phase 2에 종속된다. | W-REPORT-001 | MVP에서 숨길 Metric 범위 확인 |
| C-08 | 실시간 PNG는 완성된 제품 로그 화면이지만 실제 카메라 분석은 Phase 2다. | B-MOTION-001 | 사용자 지시에 따라 제품 UI와 mock interaction만 구현하고 실제 감지는 제외 |
| C-09 | 프로필 요약 PNG 안에 배우자 초대 Card가 있지만 Route Map은 배우자 초대를 별도 Route로 둔다. | W-PROFILE-001, W-INVITE-001 | 요약 Card는 별도 Route 진입점으로만 사용할지 확인 |
| C-10 | 이미지가 없는 Partner 화면과 예정 활동·설정 화면이 존재한다. | H-* 및 W-ACT-001, W-SETTING-001 | 요구사항 기반으로 설계할지 별도 시안 제공 여부 확인 |

## 4. 화면별 구현 계획

### 4.1 임산부 프로필 설정/수정

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-PROFILE-001` |
| 이미지 파일 | `01_1_step_due_date.png` ~ `01_7_profile_summary.png` |
| Flutter 파일 | `frontend/lib/features/profile/screens/profile_setup_screen.dart` |
| Route | `/onboarding/profile`, `/wife/profile` |
| Feature | `profile` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `ResponsivePageContent`, `AppInput`, `SelectionCard`, `AppButton`, `AppCard`, `InfoBanner`, Design Token |
| 추가로 필요한 컴포넌트 | 구현 완료: `ProfileProgress`, `ProfileWizardFrame`, `ProfileDateField`, `ProfileUnitInput`, `ProfileChoiceGrid`, `ProfileSummary`, `ProfileSetupController` |
| 이전 화면 | 최초 실행 Bootstrap 또는 Wife 전역 프로필 메뉴 |
| 다음 화면 | 최초 등록은 `/onboarding/invite`, 수정은 이전 화면 |
| Interaction | 6단계 입력, 이전/다음, 유효성 검사, Summary 항목별 수정, local/mock 저장 완료, 미저장 이탈 확인 |
| 비고 | 관련 ID: `W-PROFILE-001`, `W-PROFILE-002`, `W-PROFILE-003`. C-09는 별도 Route 계약을 우선해 Summary의 배우자 초대 Card를 제외하고 완료 후 `/onboarding/invite`로 이동 |

### 4.2 배우자 초대

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-INVITE-001` |
| 이미지 파일 | `01_8_invite_partner.png` |
| Flutter 파일 | `frontend/lib/features/profile/screens/partner_invite_screen.dart` |
| Route | `/onboarding/invite`, `/wife/invite` |
| Feature | `invitation` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard`, `AppButton`, Design Token |
| 추가로 필요한 컴포넌트 | `PartnerInvitePanel`, 초대 Link Field, Copy action, 공유 결과 Dialog, 연결 상태 Banner |
| 이전 화면 | 최초 프로필 저장 또는 미연동 상태의 Wife 프로필 메뉴 |
| 다음 화면 | 온보딩은 `/wife/home`, 수동 진입은 이전 화면 |
| Interaction | 링크 생성, 복사, OS 공유, 나중에 하기, 재시도, 생성/공유/오류 상태 |
| 비고 | 관련 ID: `W-INVITE-001`, `W-INVITE-002`. C-01~C-04 적용 확인 |

### 4.3 남편 초대 수락

| 항목 | 내용 |
| --- | --- |
| Screen ID | `H-INVITE-001` |
| 이미지 파일 | 없음 |
| Flutter 파일 | `frontend/lib/features/partner/screens/invitation_entry_screen.dart` |
| Route | `/invitation-entry?token={token}` |
| Feature | `invitation` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | `InvitationAcceptancePanel`, 검증 Loading, Error/Expired Banner, 연결 완료 Dialog |
| 이전 화면 | 외부 초대 링크 |
| 다음 화면 | 성공 시 `/partner/calendar`, 실패 시 현재 화면의 오류 상태 |
| Interaction | Token 검증, 설치/로그인 안내, 초대 수락, 만료·사용됨·중복·서버 실패 재시도 |
| 비고 | 외부 Domain과 로그인 복귀 URL은 미정. C-10 확인 필요 |

### 4.4 오늘의 컨디션

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-COND-001` |
| 이미지 파일 | `02_today_care.png` |
| Flutter 파일 | `frontend/lib/features/condition/screens/condition_screen.dart` |
| Route | `/wife/home/condition?mode=create|edit` |
| Feature | `condition` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `ResponsivePageContent`, `AppButton`, Design Token |
| 추가로 필요한 컴포넌트 | 구현 완료: `ConditionMetric`, `PainMetricCard`, `TodayCareController`, `TodayCareStore`, 이탈 확인 Dialog |
| 이전 화면 | `/wife/home` |
| 다음 화면 | 최초 입력은 `/wife/home/activity`, 수정은 `/wife/home` |
| Interaction | 심각도 선택, 부위별 통증 입력, 피로·기분 선택, 저장, 수정, 오류·로딩 처리 |
| 비고 | 관련 ID: `W-COND-001`, `W-COND-002`. 상태는 색과 Text를 함께 사용 |

### 4.5 오늘 예정 활동

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-ACT-001` |
| 이미지 파일 | 없음 |
| Flutter 파일 | `frontend/lib/features/condition/screens/activity_screen.dart` |
| Route | `/wife/home/activity` |
| Feature | `condition` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `SelectionCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | `PlannedActivitySelector`, 선택 요약, 생성 Loading/Fallback 연결 상태 |
| 이전 화면 | `/wife/home/condition` 최초 저장 |
| 다음 화면 | 루틴 생성 후 `/wife/home` |
| Interaction | 활동 복수 선택, 선택 해제, 유효성 검사, 저장, AI 루틴 생성 상태 전환 |
| 비고 | C-10: 화면 이미지가 없어 별도 시안 또는 요구사항 기반 설계 확인 필요 |

### 4.6 통합 홈

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-ROUTINE-001` |
| 이미지 파일 | `02_0_home_before_check.png`, `04_0_home_merged.png` |
| Flutter 파일 | `frontend/lib/features/home/screens/wife_home_screen.dart`, `frontend/lib/features/routine/**` |
| Route | `/wife/home` |
| Feature | `routine` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `ResponsivePageContent`, `SectionHeader`, `AppButton`, `AppLoadingState`, `InfoBanner`, Design Token |
| 추가로 필요한 컴포넌트 | 구현 완료: `PregnancyWeekHero`, `PregnancyWeekTipCard`, `RoutineGuideCard`, `DailyRoutinePlan`, `RoutineService`, `MockRoutineService`, `DailyRoutineController` |
| 이전 화면 | Bootstrap, 배우자 초대 종료, 예정 활동 저장 |
| 다음 화면 | 컨디션, 식사·가사·건강·수면, Daily 리포트, 전역 프로필 메뉴 |
| Interaction | 컨디션 미입력/입력 완료 조건부 UI, 가이드 진입, 컨디션 수정, 루틴 생성 Loading/Fallback, 하루 끝내기 |
| 비고 | 관련 ID: `W-ROUTINE-001`, `W-ROUTINE-002`, `W-ROUTINE-003`. C-01, C-03 적용. `04_0_home_merged.png`에는 Timeline·카드별 시각·완료 Badge가 없어 추가하지 않았으며, `10_routine_record.png`는 W-REPORT-001 범위로 분리 |

### 4.7 식사 가이드

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-MEAL-001` |
| 이미지 파일 | `05_0_meal_select.png`, `05_meal_guide.png` |
| Flutter 파일 | `frontend/lib/features/meal/screens/meal_guide_screen.dart` |
| Route | `/wife/home/meal` |
| Feature | `meal` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `ResponsivePageContent`, `AppCard`, `AppButton`, `AppBadge`, `SectionHeader`, 상태 Component |
| 추가로 필요한 컴포넌트 | 구현 완료: `MealPeriodCard`, `MealRecommendationCard`, `MealInfoSection`, `MealGuideController`, `MealService`, `MockMealService`, `MealSelectionStore` |
| 이전 화면 | `/wife/home` 또는 식사 Chat 적용 결과 |
| 다음 화면 | `/wife/meal-chat` 또는 `/wife/home` |
| Interaction | 끼니 선택, 추천 Loading/Empty/Error, 추천 수락·거절, 재추천, 공유, 완료 기록 |
| 비고 | 관련 ID: `W-MEAL-001`, `W-MEAL-002`, `W-MEAL-003`, `W-MEAL-004`, `W-RECORD-001`. C-01, C-03 적용. 원본 이미지에 없는 냉장고 재료 목록·조리법·가전 실행 UI는 추가하지 않음 |

### 4.8 가사 가이드

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-HOUSE-001` |
| 이미지 파일 | `07_home_guide_B_smart_routine.png`, `07_1_home_guide_share_done.png`, `07_2_home_guide_partner_status.png` |
| Flutter 파일 | `frontend/lib/features/household/screens/household_guide_screen.dart` |
| Route | `/wife/home/household` |
| Feature | `household` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard`, `AppButton`, `SelectionCard` |
| 추가로 필요한 컴포넌트 | `HouseholdTaskGroup`, `GuideTaskCard`, `HouseholdShareSelector`, `RequestStatusView`, `PartnerShareResultDialog`, `StatusBadge` |
| 이전 화면 | `/wife/home` |
| 다음 화면 | 요청 전송 후 현재 화면 또는 `/wife/home` |
| Interaction | 직접/가전/가족 분담 확인, 복수 선택, 파트너 공유, 성공 Modal, 요청·확인·완료 상태 갱신 |
| 비고 | 관련 ID: `W-HOUSE-001`, `W-HOUSE-002`, `W-HOUSE-003`, `W-RECORD-002`. C-04, C-06 확인 필요 |

### 4.9 공유 실시간 모션

| 항목 | 내용 |
| --- | --- |
| Screen ID | `B-MOTION-001` |
| 이미지 파일 | `11_realtime.png` |
| Flutter 파일 | `frontend/lib/features/movement/product_movement_screen.dart` |
| Route | `/wife/movement`, `/partner/movement` |
| Feature | `movement` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard` |
| 추가로 필요한 컴포넌트 | 구현 완료: `RealtimeAlertController`, `MovementAlertCard`, 상태 Toggle, severity 표시, Alert 상세 Bottom Sheet |
| 이전 화면 | 역할별 하단 Navigation의 이전 Tab |
| 다음 화면 | 역할별 Home 또는 Calendar Tab |
| Interaction | mock 감지 ON/OFF, severity별 로그 선택, 추천 행동 확인, Alert 확인 처리, 아내의 가사 Routine 이동 |
| 비고 | 최신 공통 ID `B-MOTION-001`. 기존 `MovementScreen` 카메라 데모와 별도이며 감지·판정·로그·확인 상태는 local mock |

### 4.10 건강 가이드

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-HEALTH-001` |
| 이미지 파일 | `08_body_care_guide.png` |
| Flutter 파일 | `frontend/lib/features/health/screens/health_guide_screen.dart` |
| Route | `/wife/home/health` |
| Feature | `health` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | `BodyLoadSummary`, `ProgressMetric`, `HealthActivityCard`, 영상 Thumbnail, `InfoBanner`, 완료 상태 Control |
| 이전 화면 | `/wife/home` |
| 다음 화면 | 완료 후 현재 화면 또는 `/wife/home`; 결과는 Daily 리포트에 반영 |
| Interaction | 부위별 부담 조회, 콘텐츠 열기, 영상/자세 보기, 완료 체크, Loading/Empty/Error |
| 비고 | 관련 ID: `W-HEALTH-001`, `W-HEALTH-002`, `W-RECORD-001`. MVP는 모션 데이터 대신 컨디션 기반 |

### 4.11 수면 가이드

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-SLEEP-001` |
| 이미지 파일 | `09_sleep_care.png` |
| Flutter 파일 | `frontend/lib/features/sleep/screens/sleep_guide_screen.dart` |
| Route | `/wife/home/sleep` |
| Feature | `sleep` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard`, `AppButton`, `SelectionCard` |
| 추가로 필요한 컴포넌트 | 구현 완료: `SleepEnvironmentCard`, `SleepGuideController`, `SleepService`, `MockSleepService`, 설정 Bottom Sheet |
| 이전 화면 | `/wife/home` |
| 다음 화면 | 완료 후 현재 화면 또는 `/wife/home`; 결과는 Daily 리포트에 반영 |
| Interaction | 환경 항목 복수 선택, 값 수정, 추천값 복원, 루틴 시작, Mock 완료/실패 상태 |
| 비고 | 관련 ID: `W-SLEEP-001`, `W-SLEEP-002`, `W-RECORD-001`. 센서·Wearable·ThinQ Device API 없이 local/mock 상태만 사용 |

### 4.12 식사 재조정 채팅

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-CHAT-001` |
| 이미지 파일 | `12_chat.png`, `12_1_chat_meal_rechoose.png` |
| Flutter 파일 | `frontend/lib/features/meal/screens/meal_chat_screen.dart` |
| Route | `/wife/meal-chat` |
| Feature | `meal` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `ResponsivePageContent`, `AppInput`, `AppButton` |
| 추가로 필요한 컴포넌트 | 구현 완료: `MealChatBubble`, 재사용 `MealRecommendationCard`, `MealChatController`, 식사 Context Composer |
| 이전 화면 | 식사 가이드 또는 Wife Chat Tab |
| 다음 화면 | 추천 적용 시 `/wife/home/meal` |
| Interaction | 메시지 작성·전송, 빠른 답변, 응답 대기·실패, 재추천 반복, 추천 적용, Draft 이탈 확인 |
| 비고 | 관련 ID: `W-MEAL-002`, `W-CHAT-001`. C-05에 따라 `12_chat.png`의 식사 외 건강·가사 대화는 제외하고 `12_1_chat_meal_rechoose.png`의 Meal 재추천 범위만 구현. `W-CHAT-002`는 Phase 2 유지 |

### 4.13 Daily 리포트

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-REPORT-001` |
| 이미지 파일 | `10_routine_record.png`, `10_1_report_share_done.png` |
| Flutter 파일 | `frontend/lib/features/report/screens/daily_report_screen.dart` |
| Route | `/wife/calendar/report/:date` |
| Feature | `report` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | 구현 완료: `ReportMetricCard`, `RoutineRecordCard`, `DailyReportController`, `RecordService`, `MockRecordService`, 공유 결과 Dialog |
| 이전 화면 | Home 하루 끝내기 또는 Wife Calendar 날짜 선택 |
| 다음 화면 | `/wife/calendar` 또는 공유 결과 Modal 후 현재 화면 |
| Interaction | 날짜별 기록 조회, 영역별 상태 확인, 저장·마치기, 파트너 공유, Loading/Empty/Error |
| 비고 | 관련 ID: `W-REPORT-001`, `W-REPORT-002`. DB 저장·실제 공유 없이 날짜별 Mock Record와 local feedback 사용 |

### 4.14 컨디션 캘린더

| 항목 | 내용 |
| --- | --- |
| Screen ID | `B-CAL-001` |
| 이미지 파일 | `13_condition_calendar.png` |
| Flutter 파일 | `frontend/lib/features/calendar/screens/wife_calendar_screen.dart` |
| Route | `/wife/calendar` |
| Feature | `report` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard` |
| 추가로 필요한 컴포넌트 | 구현 완료: `ConditionCalendar`, `ConditionLegend`, `RecordDaySummary`, `RecordCalendarController` |
| 이전 화면 | Wife Calendar Tab 또는 Daily 리포트 |
| 다음 화면 | `/wife/calendar/report/:date` |
| Interaction | 월 이동, 날짜 선택, Keyboard 탐색, 상태 legend 확인, 선택 날짜 리포트 이동 |
| 비고 | 최신 요구사항 `B-CAL-001`을 아내·파트너 Route가 공유. Material Grid를 사용해 대형 Calendar dependency를 추가하지 않음 |

### 4.15 설정

| 항목 | 내용 |
| --- | --- |
| Screen ID | `W-SETTING-001` |
| 이미지 파일 | 없음 |
| Flutter 파일 | `frontend/lib/features/settings/screens/wife_settings_screen.dart` |
| Route | `/wife/settings` |
| Feature | `settings` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard` |
| 추가로 필요한 컴포넌트 | 상세 요구사항 확정 전 정의하지 않음 |
| 이전 화면 | Wife 전역 프로필 메뉴 |
| 다음 화면 | 이전 화면 |
| Interaction | 현재는 Phase 2/준비 중 안내만 허용 |
| 비고 | 상세 설정 요구사항 미정. C-10 확인 전 임의 항목 추가 금지 |

### 4.16 파트너 아침 리포트

| 항목 | 내용 |
| --- | --- |
| Screen ID | `H-REPORT-001` |
| 이미지 파일 | 없음 |
| Flutter 파일 | `frontend/lib/features/partner/screens/partner_morning_report_screen.dart` |
| Route | `/partner/report/:date` |
| Feature | `report` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | `PartnerMorningSummary`, `ConditionSummaryBanner`, 읽기 전용 `GuideTaskCard`, `FamilyParticipationSummary` |
| 이전 화면 | Partner 알림 또는 Calendar 날짜 선택 |
| 다음 화면 | 파트너 가사 요청 또는 이전 화면 |
| Interaction | 날짜별 공유 데이터 조회, 요청 상세 진입, Calendar 이동, Loading/Empty/Error |
| 비고 | 공유 허용 데이터만 표시. C-10: 전용 이미지 없음 |

### 4.17 파트너 캘린더

| 항목 | 내용 |
| --- | --- |
| Screen ID | `B-CAL-001` Partner Variant |
| 이미지 파일 | 없음; `13_condition_calendar.png`의 구조만 읽기 전용 Variant 참고 가능 |
| Flutter 파일 | `frontend/lib/features/partner/screens/partner_calendar_screen.dart` |
| Route | `/partner/calendar` |
| Feature | `report` |
| 구현 상태 | `IMPLEMENTED` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppBottomNavigation`, `AppCard` |
| 추가로 필요한 컴포넌트 | 아내 화면과 동일한 `RecordCalendarScreen`, `ConditionCalendar`, `RecordDaySummary` 재사용 |
| 이전 화면 | 계정 연동 완료 또는 Partner Bootstrap |
| 다음 화면 | 아침 리포트, 알림, 가사 요청, 파트너 프로필 |
| Interaction | 월 이동, 날짜 선택, 읽기 전용 기록 조회, Header 알림·프로필 진입 |
| 비고 | Partner Main 화면. `13_condition_calendar.png` 구조를 공유하고 알림·프로필·실시간 진입만 역할별로 추가 |

### 4.18 파트너 알림

| 항목 | 내용 |
| --- | --- |
| Screen ID | `H-NOTI-001` |
| 이미지 파일 | 없음 |
| Flutter 파일 | `frontend/lib/features/partner/screens/partner_notifications_screen.dart` |
| Route | `/partner/notifications` |
| Feature | `notification` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard` |
| 추가로 필요한 컴포넌트 | `NotificationListItem`, 읽음 Badge, Empty/Loading/Error state |
| 이전 화면 | Partner 전역 알림 Bell |
| 다음 화면 | 아침 리포트 또는 파트너 가사 요청 |
| Interaction | 목록 조회, 읽음 처리, 알림 선택, 목적 Route 이동, 빈 알림함 처리 |
| 비고 | MVP는 앱 내 Mock Inbox이며 Push Infra는 제외. C-10 확인 필요 |

### 4.19 파트너 가사 요청

| 항목 | 내용 |
| --- | --- |
| Screen ID | `H-REQUEST-001` |
| 이미지 파일 | 없음; `07_2_home_guide_partner_status.png`는 아내 측 상태 표시 참고 |
| Flutter 파일 | `frontend/lib/features/partner/screens/partner_request_screen.dart` |
| Route | `/partner/requests/:requestId` |
| Feature | `household` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard`, `AppButton` |
| 추가로 필요한 컴포넌트 | `PartnerRequestCard`, 상태 Step, `StatusBadge`, 처리 Loading/Error feedback |
| 이전 화면 | Partner 알림, 아침 리포트 또는 Calendar |
| 다음 화면 | 상태 처리 후 현재 Detail 유지 또는 이전 화면 |
| Interaction | 요청 조회, 확인 처리, 완료 처리, 허용 상태 전이, 잘못된 requestId 오류 |
| 비고 | 관련 ID: `H-REQUEST-001`, `H-REQUEST-002`, `H-REQUEST-003`. C-10: 전용 이미지 없음 |

### 4.20 파트너 프로필

| 항목 | 내용 |
| --- | --- |
| Screen ID | `H-PROFILE-001` |
| 이미지 파일 | 없음; `01_7_profile_summary.png`의 정보 구획만 읽기 전용 Variant 참고 가능 |
| Flutter 파일 | `frontend/lib/features/partner/screens/partner_profile_screen.dart` |
| Route | `/partner/profile` |
| Feature | `profile` |
| 구현 상태 | `SKELETON` |
| 사용해야 하는 공용 컴포넌트 | `TopAppBar`, `AppCard` |
| 추가로 필요한 컴포넌트 | `ProfileSummary.readOnlyPartner`, 연결 상태 Banner, Loading/Empty/Error state |
| 이전 화면 | Partner 전역 프로필 버튼 |
| 다음 화면 | 이전 화면 |
| Interaction | 연결된 프로필 읽기 전용 조회, 연결 전·데이터 없음·오류 상태 |
| 비고 | 수정 Action을 제공하지 않는다. C-10: 전용 이미지 없음 |

## 5. 공통 UI 준비 상태

`docs/screens/**` 24개 이미지의 반복 Pattern을 기준으로 실제 Screen 구현 전에 다음 기반을 준비했다. 세 화면 이상에서 반복되는 표현만 Design System에 포함했고, Domain 상태에 종속된 요소는 Feature 구현 시점까지 보류했다.

| 구분 | 준비된 항목 | 비고 |
| --- | --- | --- |
| Token | `AppBreakpoints`, 누락된 Primary·Semantic·Category Color | `DESIGN.md` 값을 그대로 코드화 |
| Layout | `ResponsivePageContent` | Form 560px, 일반 Page 720px 최대 폭 지원 |
| 정보 구조 | `SectionHeader` | 제목·설명·선택적 보조 Action |
| 상태 표현 | `InfoBanner`, `AppBadge` | `StatusBadge`, `CategoryBadge`를 별도 중복 생성하지 않음 |
| 비동기 상태 | `AppLoadingState`, `AppEmptyState`, `AppErrorState` | Loading·Empty·Error와 선택적 복구 Action |
| 반복 Task | `GuideTaskCard` | 가사·건강·리포트의 공통 골격만 담당 |
| Form | 확장된 `AppInput` | 도움말·오류·Icon·입력 유형·제출 이벤트 지원 |

프로필, 컨디션, Home, 식사, 가사, 건강, 수면, 리포트, 모션, Partner 전용 Component는 각 Domain 상태가 확정되는 실제 Screen 구현 시 해당 Feature의 `widgets/`에 추가한다. 상세 판단은 `docs/development/06_common_ui_gap_analysis.md`를 따른다.

공통 기반 준비 이후 Profile, Today Care, Home, Meal, Household, `B-MOTION-001`, Health, Sleep, Chat, Daily Report와 `B-CAL-001` 역할별 Calendar를 실제 UI로 구현했으며, 그 외 제품 화면은 `SKELETON`으로 유지한다.

## 6. 구현 순서

Source 충돌이 해소된 이후 다음 순서로 진행한다.

1. 공통 Foundation 누락분: Responsive, semantic/category token, Loading/Empty/Error, 공통 Dialog
2. 프로필 Domain Component와 `W-PROFILE-001`
3. 초대·컨디션·예정 활동
4. 통합 홈과 역할별 Shell 검증
5. 식사·건강·수면·가사 Vertical Slice
6. 식사 Chat과 요청 상태 흐름
7. Daily 리포트와 Wife Calendar
8. Partner 리포트·캘린더·알림·요청·프로필
9. Phase 2 결정 후 설정·실시간 모션

각 화면은 `SKELETON → IN_PROGRESS → IMPLEMENTED → VERIFIED` 순으로만 변경한다.
