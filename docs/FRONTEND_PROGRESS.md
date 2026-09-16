# Frontend Status

이 문서는 다음 개발자가 Placeholder를 실제 UI로 교체할 때의 현재 상태와 공용 파일 경계를 기록한다.

## Foundation

| 영역 | 상태 | 비고 |
| --- | --- | --- |
| Design System | DONE | Color, spacing, radius, typography token |
| Theme | DONE | `AppTheme.light`를 최상위 `MaterialApp`에 적용 |
| Shared Components | DONE | Button, Input, Card, SelectionCard, TopAppBar, BottomNavigation |
| Routing | DONE | Flutter 기본 Navigator 기반 중앙 route 생성 |
| Navigation | DONE | ROUTE_MAP의 전체 화면 진입 및 주요 이동 관계 연결 |
| Backend 연동용 상태/Service | TODO | 이번 Skeleton 범위에서 제외 |

## Screens

| ID | 화면 | 상태 |
| --- | --- | --- |
| SCR-W-01 | 임산부 프로필 설정 | SKELETON |
| SCR-W-14 | 배우자 초대 | SKELETON |
| SCR-H-06 | 초대 수락 | SKELETON |
| SCR-W-02 | 오늘의 컨디션 | SKELETON |
| SCR-W-03 | 오늘 예정 활동 | SKELETON |
| SCR-W-04 | 통합 홈 | SKELETON |
| SCR-W-05 | 식사 가이드 | SKELETON |
| SCR-W-06 | 가사 가이드 | SKELETON |
| SCR-W-07 | 실시간 모션 | SKELETON / DEFERRED PHASE 2 |
| SCR-W-08 | 건강 가이드 | SKELETON |
| SCR-W-09 | 수면 가이드 | SKELETON |
| SCR-W-10 | 식사 재조정 채팅 | SKELETON |
| SCR-W-11 | Daily 리포트 | SKELETON |
| SCR-W-12 | 컨디션 캘린더 | SKELETON |
| SCR-W-13 | 설정 | SKELETON / BLOCKED PHASE 2 |
| SCR-H-01 | 파트너 아침 리포트 | SKELETON |
| SCR-H-02 | 파트너 캘린더 | SKELETON |
| SCR-H-03 | 알림 | SKELETON |
| SCR-H-04 | 파트너 가사 요청 | SKELETON |
| SCR-H-05 | 파트너 프로필 | SKELETON |

`SCR-W-07`은 제품용 Placeholder이며 기존 모션 데모 구현을 삭제하지 않는다. `SCR-W-13`은 요구사항이 확정되기 전까지 임의 설정 항목을 추가하지 않는다.

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
- `flutter test`: 17개 통과
- `flutter build web`: 통과
- Router test: 전체 20개 제품 경로, 핵심 온보딩 흐름, 동적 report/request 경로, 404 처리 확인
