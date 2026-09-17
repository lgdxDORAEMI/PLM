# 화면 구현 매핑 V2

작성일: 2026-09-18

## 공통·아내 화면

| 화면 ID | 화면 | Route / 표시 방식 | 실제 구현 | 상태 |
|---|---|---|---|---|
| B-ENTRY-001 | 앱 진입 | /, /entry | AppRouter guard, 연결 필요 안내 | 일부 완료 |
| W-PROFILE-001~006 | 프로필 입력 | /wife/profile/onboarding/:step | ProfileSetupScreen | 완료 |
| W-PROFILE-007 | 프로필 확인 | onboarding/edit summary | ProfileSetupScreen | 완료 |
| W-INVITE-001 | 남편 초대 | /wife/invite | PartnerInviteScreen | 일부 완료 |
| W-HOME-001 | 아내 Home | /wife/home | WifeHomeScreen | 완료 |
| W-COND-001 | 오늘 컨디션 | /wife/condition | ConditionScreen | 완료 |
| W-TASK-001 | 예정 활동 | /wife/tasks | ActivityScreen | 완료 |
| W-CALLBACK-001 | AI 생성 실패 | /wife/routine/fallback | RoutineFallbackScreen | 완료 |
| W-MEAL-001 | 식사 목록 | /wife/meal | MealGuideScreen | 완료 |
| W-MEAL-002 | 식사 상세 | /wife/meal/:mealKey | MealGuideScreen(initialPeriod) | 완료 |
| W-CHAT-001 | 식사 재조정 | /wife/chat | MealChatScreen | 일부 완료 |
| W-CHAT-002 | 전체 루틴 대화 | Phase 2 안내 | 현재 지원 범위 안내 | 제외 |
| W-HOUSE-001 | 가사 가이드 | /wife/house | HouseholdGuideScreen | 일부 완료 |
| W-HOUSE-003-1 | 요청 완료 | Dialog | 가사 화면 Dialog | 완료 |
| W-HEALTH-001/002 | 건강 가이드·완료 | /wife/health | HealthGuideScreen | 완료 |
| W-SLEEP-001 | 수면 가이드 | /wife/sleep | SleepGuideScreen | 완료 |
| W-SLEEP-002 | 수면 환경 설정 | Bottom Sheet | 수면 화면 Bottom Sheet | 완료 |
| W-REPORT-001 | Daily Report | /wife/report/:date | DailyReportScreen | 일부 완료 |
| W-REPORT-001-1 | Report 공유 완료 | Dialog | Report 화면 Dialog | 완료 |
| W-MENU-001 | 메뉴 | /wife/menu | WifeMenuScreen | 완료 |
| B-CAL-001 | 아내 Calendar | /wife/calendar | WifeCalendarScreen | 일부 완료 |
| B-MOTION-001 | 아내 실시간 | /wife/live | ProductMovementScreen | 일부 완료 |

아내 Bottom Navigation: /wife/home, /wife/live, /wife/chat, /wife/calendar.

## 남편 화면

| 화면 ID | 화면 | Route / 표시 방식 | 실제 구현 | 상태 |
|---|---|---|---|---|
| B-ENTRY-001 | 연결 전 진입 | /entry | 연결 필요 안내 | 일부 완료 |
| 초대 handoff | 초대 수락 | /invite/accept?token=... | InvitationEntryScreen | 일부 완료 |
| B-CAL-001 | Calendar Home | /husband/calendar | PartnerCalendarScreen | 완료 |
| H-REPORT-001 | 오전 컨디션 Report | /husband/report/morning/:date | PartnerMorningReportScreen | 완료 |
| Daily Report | 날짜별 상세 | /husband/report/daily/:date | 읽기 전용 Report 화면 | 확인 필요 |
| H-NOTI-001 | 알림 | /husband/notifications | PartnerNotificationsScreen | 일부 완료 |
| H-REQUEST-001 | 가사 요청 | /husband/requests/:requestId | PartnerRequestScreen | 일부 완료 |
| 완료 확인 | 요청 완료 확인 | Dialog | Request 화면 Dialog | 완료 |
| H-REQUEST-002 | 요청 결과 | /husband/requests/:requestId/result | PartnerRequestResultScreen | 완료 |
| B-MOTION-001 | 남편 실시간 | /husband/live | 읽기 전용 ProductMovementScreen | 일부 완료 |

남편 화면설계서에 Bottom Navigation이 없으며 Calendar가 기본 Home이다.

## Route 정합성과 미사용 항목

- ROUTE_MAP_V2의 공통, 아내, 남편, 초대, 역할 전환 route가 AppRouter에 연결돼 있다.
- /role/switch/:targetRole 외부 URL은 역할을 바꾸지 않으며 명시적 AppRouter.switchRole만 전환한다.
- 잘못된 역할 route는 현재 역할 Home으로 redirect되고 최초 URL도 교체된다.
- 새로고침 시 저장된 activeRole과 route 유효성을 함께 검사한다.
- features/entry/EntryScreen은 router에서 사용하지 않는 삭제 후보이다.
- partnerMorningReportPattern, partnerRequestPattern은 참조 없는 과거 호환 별칭이다.
- 설정은 상세 요구사항이 없어 Placeholder이며 알 수 없는 URL은 안전한 fallback으로 처리한다.

## DB와 UI 연결

| DB 영역 | 연결 화면 | 구현 상태 |
|---|---|---|
| Profile·Pregnancy | 프로필, Home, Meal, Report | local profile store; API 필요 |
| Daily condition·activity | Home, 컨디션, 활동, Report, Calendar | local/mock service |
| Routine·meal·chat | Home, 가이드, 채팅 | mock service; AI API 필요 |
| Household request | 아내 가사, 남편 Request, Calendar | 공유 local store; DB API 필요 |
| Sleep·health | 가이드, Report | local/mock service |
| Calendar·Report | 양쪽 Calendar, 오전/Daily Report | mock record service |
| Notification | 남편 Notification | local store; push API 필요 |
| Realtime event | 양쪽 실시간 | mock controller; 장치 API 필요 |
| Invitation·role | 초대, 진입, 사용자 전환 | local session/store; ThinQ API 필요 |