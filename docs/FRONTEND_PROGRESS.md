# Frontend Status

이 문서는 다음 개발자가 Placeholder를 실제 UI로 교체할 때의 현재 상태와 공용 파일 경계를 기록한다.

## Foundation

| 영역 | 상태 | 비고 |
| --- | --- | --- |
| Design System | DONE | Color, spacing, radius, typography token |
| Theme | DONE | `AppTheme.light`를 최상위 `MaterialApp`에 적용 |
| Shared Components | DONE | Button, Input, Card, SelectionCard, TopAppBar, BottomNavigation |
| Routing | PARTIAL | 중앙 Path·동적 Parameter·Bootstrap Resolver 계약 구현, 실제 Session Guard TODO |
| Navigation | DONE | 역할별 Header, Wife 4개/Partner 2개 Tab과 서비스 흐름 연결 |
| Backend 연동용 상태/Service | TODO | 이번 Skeleton 범위에서 제외 |

## Screens

| 대표 요구사항 ID | 화면 | 상태 |
| --- | --- | --- |
| W-PROFILE-001 | 임산부 프로필 설정/수정 | IMPLEMENTED |
| W-INVITE-001 | 배우자 초대 | SKELETON |
| H-INVITE-001 | 초대 수락 | SKELETON |
| W-COND-001 | 오늘의 컨디션 | IMPLEMENTED |
| W-ACT-001 | 오늘 예정 활동 | SKELETON |
| W-ROUTINE-001 | 통합 홈 | IMPLEMENTED |
| W-MEAL-001 | 식사 가이드 | IMPLEMENTED |
| W-HOUSE-001 | 가사 가이드 | IMPLEMENTED |
| B-MOTION-001 | 실시간 모션·상태 알림 | IMPLEMENTED / MOCK UI |
| W-HEALTH-001 | 건강 가이드 | IMPLEMENTED |
| W-SLEEP-001 | 수면 가이드 | IMPLEMENTED / MOCK DEVICE |
| W-CHAT-001 | 식사 재조정 채팅 | IMPLEMENTED |
| W-REPORT-001 | Daily 리포트 | IMPLEMENTED / MOCK DATA |
| B-CAL-001 | 컨디션 캘린더 | IMPLEMENTED / WIFE·PARTNER SHARED |
| W-SETTING-001 | 설정 | SKELETON / BLOCKED PHASE 2 |
| H-REPORT-001 | 파트너 아침 리포트 | SKELETON |
| H-CAL-001 | 파트너 캘린더 | IMPLEMENTED / B-CAL-001 VARIANT |
| H-NOTI-001 | 알림 | SKELETON |
| H-REQUEST-001 | 파트너 가사 요청 | SKELETON |
| H-PROFILE-001 | 파트너 프로필 | SKELETON |

`B-MOTION-001`은 역할별 Route가 공유하는 제품 UI이며 움직임 감지, severity, 알림과 확인 상태는 mock이다. `W-SLEEP-002`의 수면 환경 실행과 Record/Calendar의 날짜별 기록·저장·공유도 local mock이며 외부 API를 호출하지 않는다. 기존 모션 데모 구현은 별도로 보존한다. `W-SETTING-001`은 요구사항이 확정되기 전까지 임의 설정 항목을 추가하지 않는다.

## Route Contract

- 프로필: `/onboarding/profile`(최초), `/wife/profile`(수정)
- 배우자 초대: `/onboarding/invite`(온보딩), `/wife/invite`(수동 재진입)
- 초대 수락: `/invitation-entry?token={token}`
- 리포트/요청: `:date`, `:requestId`를 화면에 전달
- 공유 실시간: `/wife/movement`, `/partner/movement`
- 실제 인증·역할 Redirect와 외부 Deep Link Domain은 아직 연결 대상이 아님

## Shared Files

다음 파일은 여러 개발자가 동시에 수정하면 충돌 가능성이 높은 공용 영역이다. 화면 작업자는 가급적 자신의 `features/<feature>/screens` 내부만 수정하고 공용 변경은 Integration Owner와 조율한다.

```text
lib/app.dart
lib/routing/*
lib/design_system/*
lib/shared/widgets/product_skeleton_screen.dart
```

## Backend Integration

다음 항목은 Frontend Skeleton 완료 여부와 무관하며 아직 제품 화면에 연결하지 않았다.

- FastAPI 제품 API
- Supabase 제품 데이터
- 외부 LLM API
- 실제 사용자 데이터
- 실제 Authentication 흐름
- 실제 API 통신
- ThinQ 가전 제어

## 검증

- `flutter analyze`: 통과
- `flutter test`: 38개 통과 (Profile·Home·Today Care·Routine·Meal UI/Controller와 기존 회귀 테스트)
- `flutter build web`: 통과
- Router test: 20개 화면의 재사용 경로, Profile 6단계·Back·온보딩 흐름, Home→Today Care→Activity→Home local 상태 흐름, Routine 4종 Detail 이동, Routine→Meal→재추천 적용→Routine 복귀, 동적 date/requestId/token, 역할별 Navigation, Bootstrap Resolver, 404 처리 확인
