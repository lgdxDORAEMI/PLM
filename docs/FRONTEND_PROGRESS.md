# Frontend 진행 상태 — Screen ID별 최종 QA

세부 43개 Screen ID/Actor variant의 Requirement·Route·구현 파일·상태·검증은 [SCREEN_IMPLEMENTATION_MAP.md](SCREEN_IMPLEMENTATION_MAP.md)를 따른다. 기준: 최신 유스케이스·기능/비기능 요구사항, `화면설계서0916.pdf`, `docs/screens/**`, `ROUTE_MAP.md`, `DESIGN.md`, `frontend/lib/**`.

| 영역 | 실제 상태 |
|---|---|
| Design System / 공통 컴포넌트 | 토큰·Theme·Form·상태·AppBar·Wife 하단 Navigation 적용. Partner는 하단 Navigation/프로필 버튼 없음. |
| `/entry` | Mock EntryService가 loading/오류/재시도와 상태별 출발 경로 제공. ThinQ Host 배너/메뉴, 실제 세션·역할 Guard는 미연동. |
| Wife Onboarding/Menu | 6단계 Profile·수정 Summary 복귀, LMP+280일/주수 계산, 필수 선택 전 다음 버튼 비활성, 앱 실행 중 Profile Store·Home/Menu 주수 반영, Invite Mock, 연동 전/후 Menu. 브라우저 재시작 후 프로필 복원/실제 초대 전송 미연동. |
| Wife Home/Condition/Routine | 컨디션 전/후·loading/success/fallback, 네 가이드, 실제 실행일 Report 경로. 저장/AI/리포트 생성은 Mock. |
| Meal/Household/Health/Sleep/Chat | 기능별 다른 콘텐츠 구조와 선택·완료·요청·Sheet·대화 상태. 실제 가전 제어/AI는 미연동. |
| Report/Calendar | 날짜 Parameter·선택 날짜 연계/Report 복귀, Mobile 세로/Tablet·Desktop split, loading/empty/error. 오늘 저장 시 Home 컨디션 초기화. Mock 기록 기반이며 미연동 모션·가전 실행 횟수는 0. |
| Partner | Calendar→알림/날짜 Report/요청 상세→완료→Calendar. Join은 개발 중 안내만, 실제 수락/연동 없음. |
| Motion | Wife 실시간 탭 / Partner Calendar CTA, 현재·최신 이벤트·오늘 로그·기기 상태의 공유 Local Mock. Camera/MediaPipe/Sensor Phase 2. |
| Settings | 요구사항 상세 미확정: Placeholder만 제공. |

## 검증 범위

- `test/routing/screen_viewport_matrix_test.dart`: 23개 직접 Route를 각 390×900, 768×900, 1280×900에서 렌더링해 overflow/예외, Partner Navigation 분리 검사. Profile/Invite/Sleep/Dialog 같은 내부 상태는 각 기능 테스트로 검증.
- 기능·상태·Interaction: Profile Wizard 수정/검증, Home→Condition→Activity→Routine, 4 Guide, Chat 재추천, Household→Partner Request, Calendar 날짜→Report, Notifications→상세, Sleep 다섯 Sheet, Motion Mock/Actor 분리.
- 접근성: 상태 텍스트/아이콘 중복 전달, Semantics label/live region, Header action tooltip과 기본 touch target 등을 점검. 텍스트 토큰 대비 4.5:1 자동 검사와 대표 5개 Route의 390px·200% 글자 확대 검사 추가. 전 UI 대비 도구 인증, 스크린리더 실기기·브라우저 전체 키보드 탐색·디자인 픽셀 비교는 범위 밖이다.
- 필수 실행 결과: `flutter analyze` 이슈 0개, `flutter test` 71개 통과, `flutter build web` 성공. 390/768/1280px Route 매트릭스와 대표 화면의 200% 확대 검사 포함. 예정일/LMP 입력 전환 보정도 전체 테스트에서 재검증했다.

## 남은 외부 연동 / 알려진 한계

ThinQ Host Entry와 사용자 Session/Role Guard, 프로필·캘린더 서버 저장, 공유/알림 Push, 실제 LLM, ThinQ 제어, 모션 분석은 이 Frontend Mock 범위를 넘어선다. `/entry`의 기본 Mock 상태는 아내 프로필 미완료이며 브라우저를 새로 열어도 영구 로그인/프로필 상태를 복원하지 않는다. 직접 `/wife/**`·`/partner/**` URL의 권한 검증은 실제 세션 Adapter 통합 이후 적용해야 한다. 데모 기록은 샘플 날짜 중심이며 실제 오늘 데이터를 대체하지 않는다.

## 2026-09-17 푸시 후 요구사항 재감사 및 수정 계획

초기 Frontend 통합 결과를 커밋·푸시한 뒤 UC1/UC7, FUC-W-PROFILE-001/003/004/008, FUC-W-REPORT-001, NFR-022/025와 PDF p.7·31~34를 다시 대조했다. UC1의 나이 항목은 최신 FUC-W-PROFILE-002 및 DESIGN.md의 명시적 제외와 충돌하므로 추가하지 않았다.

| 우선순위 | 차이/남은 Task | 처리 상태 |
|---|---|---|
| P0 | LMP 산출 예정일·주수와 Profile 수정 값이 Home/Menu에 반영되지 않음 | 앱 실행 중 로컬 저장·주수 계산 및 재진입 반영 완료; 실제 추천 입력/서버 저장은 P1 |
| P0 | 초산/경산·단태/다태 미선택 시 다음 버튼이 눌림 | 비활성화 완료 |
| P0 | Report 저장 후 Calendar 선택일이 사라지고 오늘 Home이 초기화되지 않음 | 날짜 유지·오늘 컨디션 초기화 완료; 실제 리포트 생성/저장은 P1 |
| P0 | Phase 2 모션·가전 실행 횟수가 Mock 기록에 실적처럼 표시됨 | 두 횟수 모두 0으로 변경; 기기 제어는 구현하지 않음 |
| P1 | NFR-022의 보조 텍스트 대비 부족, NFR-025의 확대 시 공통 버튼 overflow | 토큰 대비·390px 대표 화면 200% 확대 검사 및 버튼 줄바꿈 수정 완료; 전체 화면·실기기 검사는 남음 |
| P1 | 실제 Profile/Today Care/루틴/Report 저장과 당일 완료 통계 생성 | 서버 계약·인증 연결 후 구현 필요; 현재 기록은 샘플 fixture |
| P1 | ThinQ Host Entry, Session/Role Guard, 초대 일회용 Token 및 Partner Join 연동 | Host/Auth 계약 후 구현 필요. 직접 Actor URL은 데모 목적으로 열림 |
| P1 | 실제 AI 루틴·Chat, 가족 공유/알림, 기기 상태 동기화 | 서비스 계약 후 Mock Adapter 교체 및 통합 테스트 필요 |
| P2 | Motion 카메라·MediaPipe·센서, ThinQ 실행/가전 제어 | MVP 범위 밖. 별도 Phase 2로 유지 |
| 검증 | NFR-022 전 UI 조합과 NFR-025 전 Route 200% 확대, 스크린리더·실기기·성능/보안 | 토큰/대표 화면 자동 검사 외에는 미인증; 제품 통합 QA 필요 |

이 목록은 완료되지 않은 항목을 구현 완료로 간주하지 않는다. 외부 계약이 필요한 P1/P2를 이번 Mock Frontend 변경으로 가장하지 않는다.
