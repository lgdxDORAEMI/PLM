# Frontend 진행 상태 — Screen ID별 최종 QA

세부 43개 Screen ID/Actor variant의 Requirement·Route·구현 파일·상태·검증은 [SCREEN_IMPLEMENTATION_MAP.md](SCREEN_IMPLEMENTATION_MAP.md)를 따른다. 기준: 최신 requirements, `화면설계서0916.pdf`, `docs/screens/**`, `ROUTE_MAP.md`, `DESIGN.md`, `frontend/lib/**`.

| 영역 | 실제 상태 |
|---|---|
| Design System / 공통 컴포넌트 | 토큰·Theme·Form·상태·AppBar·Wife 하단 Navigation 적용. Partner는 하단 Navigation/프로필 버튼 없음. |
| `/entry` | Mock EntryService가 loading/오류/재시도와 상태별 출발 경로 제공. ThinQ Host 배너/메뉴, 실제 세션·역할 Guard는 미연동. |
| Wife Onboarding/Menu | 6단계 Profile·수정 Summary 복귀, Invite Mock, 연동 전/후 Menu, Header 진입·이전 화면 복귀. 프로필 영속화/실제 초대 전송 미연동. |
| Wife Home/Condition/Routine | 컨디션 전/후·loading/success/fallback, 네 가이드, 실제 실행일 Report 경로. 저장/AI/리포트 생성은 Mock. |
| Meal/Household/Health/Sleep/Chat | 기능별 다른 콘텐츠 구조와 선택·완료·요청·Sheet·대화 상태. 실제 가전 제어/AI는 미연동. |
| Report/Calendar | 날짜 Parameter·선택 날짜 연계, Mobile 세로/Tablet·Desktop split, loading/empty/error. Mock 기록 기반. |
| Partner | Calendar→알림/날짜 Report/요청 상세→완료→Calendar. Join은 개발 중 안내만, 실제 수락/연동 없음. |
| Motion | Wife 실시간 탭 / Partner Calendar CTA, 현재·최신 이벤트·오늘 로그·기기 상태의 공유 Local Mock. Camera/MediaPipe/Sensor Phase 2. |
| Settings | 요구사항 상세 미확정: Placeholder만 제공. |

## 검증 범위

- `test/routing/screen_viewport_matrix_test.dart`: 23개 직접 Route를 각 390×900, 768×900, 1280×900에서 렌더링해 overflow/예외, Partner Navigation 분리 검사. Profile/Invite/Sleep/Dialog 같은 내부 상태는 각 기능 테스트로 검증.
- 기능·상태·Interaction: Profile Wizard 수정/검증, Home→Condition→Activity→Routine, 4 Guide, Chat 재추천, Household→Partner Request, Calendar 날짜→Report, Notifications→상세, Sleep 다섯 Sheet, Motion Mock/Actor 분리.
- 접근성: 상태 텍스트/아이콘 중복 전달, Semantics label/live region, Header action tooltip과 기본 touch target 등 코드를 점검. 스크린리더 실기기·브라우저 전체 키보드 탐색·디자인 픽셀 비교는 자동 검증 범위 밖이다.
- 필수 실행 결과: `flutter analyze` 이슈 0개, `flutter test` 66개 통과, `flutter build web` 성공. 390/768/1280px Route 매트릭스 포함.

## 남은 외부 연동 / 알려진 한계

ThinQ Host Entry와 사용자 Session/Role Guard, 프로필·캘린더 서버 저장, 공유/알림 Push, 실제 LLM, ThinQ 제어, 모션 분석은 이 Frontend Mock 범위를 넘어선다. `/entry`의 기본 Mock 상태는 아내 프로필 미완료이며 브라우저를 새로 열어도 영구 로그인/프로필 상태를 복원하지 않는다. 직접 `/wife/**`·`/partner/**` URL의 권한 검증은 실제 세션 Adapter 통합 이후 적용해야 한다. 데모 기록은 샘플 날짜 중심이며 실제 오늘 데이터를 대체하지 않는다.
