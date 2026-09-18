# Screen Implementation Map — 최종 Frontend QA

기준: `docs/requirements/03_유스케이스명세서.md`, `docs/requirements/04_1_기능요구사항명세서.md`, `docs/requirements/04_2_비기능요구사항명세서.md`, `docs/requirements/화면설계서0916.pdf`(34페이지, 각 페이지 이미지), `docs/screens/**`, `docs/development/ROUTE_MAP.md`, `DESIGN.md`, `frontend/lib/**`. 기능·권한은 최신 기능 요구사항, 화면 전환은 ROUTE_MAP, 시각 규칙은 DESIGN.md를 우선한다. Screen ID 접미 상태는 별도 Route가 아니다. 프로필 2단계는 생년월일을 입력받아 나이를 자동 계산하며 임신 전 신장·체중과 함께 관리한다.

`구현`의 **MVP UI**는 실제 Flutter 화면/상태와 Mock flow가 있다는 뜻이며 서버 저장·인증·AI·ThinQ 실행을 의미하지 않는다. **부분**은 명시한 계약이 아직 미충족, **Phase 2 Mock**은 실제 분석/제어 없이 상태만 제공, **Host 대기**는 ThinQ 본체가 필요한 화면이다. `QA`의 **3폭**은 390/768/1280px 직접 URL 렌더링·overflow 검사이며 내부 상태는 해당 기능 테스트로 확인했다. 시각 평가는 PDF/PNG의 정보 구조와 DESIGN.md의 토큰·반응형 규칙을 코드 대조한 것이며 실기기 수동 시각/스크린리더 인증을 뜻하지 않는다.

PDF 대조 페이지: p.1 Profile 005, p.2 Motion, p.3 Entry, p.4 Calendar, p.5 Invite, p.6 Sleep, p.7·26 Report, p.8~10 Profile Summary/006, p.11 Chat, p.12 Health, p.13·16 Home, p.14 Condition, p.15 Activity, p.17 Sleep Sheets, p.18 Fallback, p.19 Menu, p.20 Household, p.21 Notifications, p.22 Partner Report, p.23~25 Partner Request, p.28~30 Meal, p.31~34 Profile 001~004. p.27에는 화면 내용이 없다.

| Screen ID | Requirement | Route / 상태 | 구현 파일 | 구현 · UI / Interaction | QA |
|---|---|---|---|---|---|
| B-ENTRY-001 | FUC-B-ENTRY-001 | `/entry` | `features/entry/screens/entry_screen.dart`, `features/entry/widgets/pregnancy_entry_view.dart`, `routing/app_router.dart` | Bootstrap loading·오류·재시도와 실제 responsive Entry. 신규 Wife는 시작하기→Profile, 완료 Wife는 Home으로 자동 이동 | 이번 변경 최종 QA 대기 |
| B-ENTRY-001-1 | FUC-B-ENTRY-001 | `/entry` responsive state | 동일 | ThinQ 화면을 복제하지 않고 PLM 디자인 토큰으로 서비스 맥락·핵심 기능을 표현; 별도 Route 없음 | 이번 변경 최종 QA 대기 |
| W-PROFILE-001 | FUC-W-PROFILE-001 | `/onboarding/profile`, `/wife/profile` step 1 | `features/profile/screens/profile_setup_screen.dart`, `features/profile/models/profile_draft.dart` | 예정일/LMP picker·필수 오류·뒤로; LMP+280일 예정일 및 현재 임신 주수 계산 | 3폭·Wizard·계산 단위 |
| W-PROFILE-002 | FUC-W-PROFILE-002 | 동일 step 2 | 동일 | 생년월일 날짜 선택·신장·임신 전 체중 입력 및 필수값·범위 검증 | 3폭·Wizard |
| W-PROFILE-003 | FUC-W-PROFILE-003 | 동일 step 3 | 동일 | 초산/경산 단일 선택·미선택 시 다음 버튼 비활성 | Wizard |
| W-PROFILE-004 | FUC-W-PROFILE-004 | 동일 step 4 | 동일 | 단태/다태 단일 선택·미선택 시 다음 버튼 비활성 | Wizard |
| W-PROFILE-005 | FUC-W-PROFILE-005 | 동일 step 5 | 동일 | 알레르기 복수 선택·없어요 상호 배타 | 단위 |
| W-PROFILE-006 | FUC-W-PROFILE-006 | 동일 step 6 | 동일 | 진단 복수 선택·메모·미입력 통과 | Wizard |
| W-PROFILE-007 | FUC-W-PROFILE-007/008 | 동일 Summary | `features/profile/widgets/profile_summary.dart`, `controllers/profile_setup_controller.dart`, `data/profile_store.dart` | 행 수정 → 저장 → Summary 복귀, 생성 시 Home·수정 시 Menu; 유효한 필수값으로 완료 판정하고 브라우저 localStorage에서 Demo Profile 복원 | 이번 변경 최종 QA 대기 |
| W-INVITE-001 | FUC-W-INVITE-001/002 | `/onboarding/invite`, `/wife/invite` | `features/profile/screens/partner_invite_screen.dart` | 링크 생성·복사·Mock 전송; 온보딩→Home/메뉴→Menu. 실제 OS 공유·일회성 발급 미연동 | 3폭·Route |
| W-MENU-001 | FUC-W-MENU-001 | `/wife/menu` 미연동 | `features/menu/screens/wife_menu_screen.dart` | 프로필/초대/설정·이전 화면 복귀, 전역 Wife Header 진입 | 3폭·상태 전환 |
| W-MENU-001-1 | FUC-W-MENU-001 | `/wife/menu` 연동 | 동일, `features/invitation/data/partner_connection_store.dart` | 초대 행 제거·연동 안내; 로컬 Mock 연동 상태(실제 인증 아님) | 상태 전환 |
| W-HOME-001 | FUC-W-HOME-001 | `/wife/home` 미입력 | `features/home/screens/wife_home_screen.dart` | 저장된 프로필 주수→컨디션 CTA→주차 정보, 카드 월 대신 세로 흐름; 미등록 직접 URL은 시연용 주수 표시 | 3폭·Flow |
| W-HOME-001-1 | FUC-W-HOME-001/002 | `/wife/home` 입력/루틴 | 동일, `features/routine/**` | loading·success·fallback·재시도, 4개 가이드·진행·실제 당일 날짜 Report Route; AI/리포트 자동 생성은 Mock | 상태·Flow |
| W-COND-001 | FUC-W-COND-001/002 | `/wife/condition?mode=create\|edit` | `features/condition/screens/condition_screen.dart` | 생성/수정, 저장·이탈 확인, 예정 활동으로 이동; 서버 upsert/리포트 갱신 미연동 | 3폭·Flow |
| W-TASK-001 | FUC-W-TASK-001 | `/wife/activity` | `features/condition/screens/activity_screen.dart` | 집안일 복수 선택/직접 입력 → Mock 루틴 → Home | 3폭·Flow |
| W-CALLBACK-001 | FUC-W-CALLBACK-001 | Home 등 AI 결과 내부 상태 | `features/routine/controllers/daily_routine_controller.dart` | 오류 시 기본 루틴·다시 시도; 다른 AI 영역은 각 Mock service의 오류 상태 사용, 공통 Backend 로깅 미연동 | 상태 테스트 |
| W-MEAL-001 | FUC-W-MEAL-001 | `/wife/meal` 선택 | `features/meal/screens/meal_guide_screen.dart` | 끼니 추천 요약·현재 끼니·상세 선택 | 3폭·Flow |
| W-MEAL-002 | FUC-W-MEAL-002/004/005 | `/wife/meal` 상세 | 동일, `features/meal/widgets/**` | 추천·이유·주의/허용량·대안; 수락/공유는 로컬 Mock | 상태·Flow |
| W-MEAL-003 | FUC-W-MEAL-003 | `/wife/chat` 재추천 | `features/meal/screens/meal_chat_screen.dart` | Mock 대화→대안 적용·다시 추천 | Flow |
| W-CHAT-001 | FUC-W-CHAT-001; 002 Phase 2 | `/wife/chat` | 동일 | 메시지 누적·전송/응답/오류, 식사 재조정만 활성 | 3폭·대화 테스트 |
| W-HOUSE-001 | FUC-W-HOUSE-001/002/003 | `/wife/household` | `features/household/screens/household_guide_screen.dart` | 직접/가전/분담 3분류, 요청 생성; 실제 가전 제어 Phase 2 | 3폭·Partner Flow |
| W-HOUSE-001-1 | FUC-W-HOUSE-003-1 | 동일 Dialog | 동일 | 전송 결과/재시도 안내 Mock | Flow |
| W-HOUSE-001-2 | FUC-W-HOUSE-003, FUC-W-RECORD-002 | 동일 상태 | 동일 | Partner 확인·완료 로컬 상태 반영 | Flow |
| W-HEALTH-001 | FUC-W-HEALTH-001/002 | `/wife/health` | `features/health/screens/health_guide_screen.dart` | 부위 우선 활동·완료 체크; 모션 근거 Phase 2 | 3폭·상태 |
| W-SLEEP-001 | FUC-W-SLEEP-001/002 | `/wife/sleep` | `features/sleep/screens/sleep_guide_screen.dart` | 기록·자세·환경 다섯 항목·팁, 실제 루틴 실행 Phase 2 | 3폭·Sheet 테스트 |
| W-SLEEP-001-1 | FUC-W-SLEEP-001-1 | 조명 Sheet | 동일 | 권장 선택·변경·적용 Mock | Sheet |
| W-SLEEP-001-2 | FUC-W-SLEEP-001-1 | 온도 Sheet | 동일 | 직접 입력·0~40°C 검증 Mock | Sheet |
| W-SLEEP-001-3 | FUC-W-SLEEP-001-1 | 습도 Sheet | 동일 | 직접 입력·0~100% 검증 Mock | Sheet |
| W-SLEEP-001-4 | FUC-W-SLEEP-001-1 | 소리 Sheet | 동일 | 옵션 선택·적용 Mock | Sheet |
| W-SLEEP-001-5 | FUC-W-SLEEP-001-1 | 공기청정기 Sheet | 동일 | 모드 선택·적용 Mock | Sheet |
| W-REPORT-001 | FUC-W-REPORT-001; 002 Phase 2 | `/wife/report/:date` | `features/report/screens/daily_report_screen.dart` | 날짜별 Mock 조회·지표·루틴/가족 집계·저장/공유 Mock; 미연동 모션·가전 횟수 0, 저장 시 Calendar 선택일 복원 및 오늘 기록이면 Home 컨디션 초기화. 실제 당일 활동 집계·영속화는 미구현 | 3폭·상태·Flow |
| W-REPORT-001-1 | FUC-W-REPORT-001-1 | 동일 Dialog | 동일 | 공유 성공 안내·오류 시 재시도 Mock | Flow |
| B-CAL-001 (Wife) | FUC-B-CAL-001 | `/wife/calendar` | `features/calendar/screens/record_calendar_screen.dart`, `features/calendar/data/calendar_selection_store.dart` | 월→날짜 선택→상세→해당 날짜 Report→Calendar 선택일 유지; Desktop 2열/Mobile 세로 | 3폭·날짜 Route·복귀 |
| B-CAL-001 (Partner) | FUC-B-CAL-001 | `/partner/calendar` | 동일, `features/partner/screens/partner_calendar_screen.dart` | 공유 기록 + Partner 전용 알림/Motion CTA, 하단 메뉴·프로필 없음 | 3폭·날짜 Route |
| B-MOTION-001 (Wife) | FUC-B-MOTION-001 | `/wife/movement` | `features/movement/product_movement_screen.dart` | Phase 2 Mock: 현재·최신 이벤트·오늘 로그·기기 상태, Wife 실시간 탭 | 3폭·Mock 상태 |
| B-MOTION-001 (Partner) | FUC-B-MOTION-001 | `/partner/movement` | 동일 | Phase 2 Mock 공유 상태, Partner Calendar CTA만·하단 메뉴 없음 | 3폭·Mock 상태 |
| H-REPORT-001 | FUC-H-REPORT-001 | `/partner/report/:date` | `features/partner/screens/partner_morning_report_screen.dart` | 아침 컨디션/행동 요약 읽기 전용, 로딩·빈값·오류 | 3폭·날짜 Route |
| H-NOTI-001 | FUC-H-NOTI-001 | `/partner/notifications` | `features/partner/screens/partner_notifications_screen.dart` | 읽음/안 읽음·빈값·리포트 날짜/요청 ID 이동; Push Phase 2 | 3폭·Flow |
| H-REQUEST-001 | FUC-H-REQUEST-001/002 | `/partner/requests/:requestId` | `features/partner/screens/partner_request_screen.dart` | 요청자·사유·작업별 확인·완료, 잘못된 ID 빈값 | 3폭·Flow |
| H-REQUEST-001-1 | FUC-H-REQUEST-002 | 동일 확인 Dialog | 동일 | 아직이에요/완료했어요 분기 | Flow |
| H-REQUEST-001-2 | FUC-H-REQUEST-002 | 동일 진행 상태 | 동일 | 요청/확인/완료 개별 상태 | Flow |
| H-REQUEST-002 | FUC-H-REQUEST-003 | 동일 완료 결과 | 동일 | 반영 위치·분담 집계·Calendar 복귀 | Flow |

## PNG가 없는 Route와 보류 계약

| Requirement | Route | 상태 |
|---|---|---|
| FUC-W-SETTING-001 | `/wife/settings` | 상세 항목 미확정: 요구사항 없는 설정을 만들지 않는 Placeholder. Menu 뒤로 복귀는 앱 스택에서 동작하나 직접 URL의 뒤로 계약은 미완성. |
| FUC-H-INVITE-001 | `/partner/join?token=...` | Token 유효/만료/중복·오류 UI 및 개발 중 안내. 가입/로그인/실제 수락/계정 연동은 의도적으로 비활성. |

## 남은 정합성 Gap

- 실제 ThinQ Host shell과 인증·역할·연동 서버 상태 및 Route Guard는 Host/Auth 계약 없이 구현할 수 없다. 현재 `/entry`는 실제 Demo Entry와 Mock Bootstrap을 제공하며 직접 Actor URL 차단은 보장하지 않는다.
- Demo Profile은 브라우저 localStorage에서 복원되지만 서버 계정과 동기화되지 않는다. 초대·리포트 공유, AI 추천, 가전 제어, 실시간 모션도 실제 API를 호출하지 않는다. Menu 연동 완료 variant는 테스트용 로컬 상태이며 Partner Join에서 수락하지 않는다.
- 달력/리포트에는 2026-09-13 중심 샘플 기록과 실행일 Mock 기록이 있고 실제 루틴 완료/저장 이력과 동기화되지 않는다. 리포트의 미연동 모션·가전 실행 횟수는 0으로 표시한다. NFR-022 대비 토큰 자동 검사는 통과했지만 모든 개별 조합·도구 검사 100% 인증은 아니며, NFR-025의 200% 확대도 대표 5개 Route만 자동 확인했다. 스크린리더 실기기·실제 브라우저 hover/focus/시각 QA는 별도다.
- PDF p.3/4/17/19 및 Screen PNG는 콘텐츠·정보 구조의 참조이며 ThinQ Host 배너의 원본 시각 스타일은 PLM 화면에 복제하지 않는다.
