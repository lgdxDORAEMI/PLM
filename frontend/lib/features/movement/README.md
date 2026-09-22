# Frontend 모션 기능

모션 기능에는 일반 앱의 기록 조회 화면과 별도 카메라 기술 데모가 있습니다.

## 일반 앱

`ProductMovementScreen`은 아내의 `/wife/live`와 남편의 `/husband/live`에서 사용합니다. `ApiMovementDashboardService`가 오늘 이벤트와 일일 집계를 조회하고, 아내 화면에서는 동의·수집 설정도 읽습니다. 남편의 기록은 백엔드가 `partner_links`에 연결된 아내 범위로 제한합니다. 화면은 카메라를 시작하지 않습니다. 명시적 미리보기 또는 연동 정보가 없는 경로에서만 로컬 예시 Service를 사용할 수 있습니다.

## 카메라 기술 데모

`main_movement_debug.dart`는 일반 앱 라우터와 분리된 진입점입니다. `MovementController`가 `BrowserCameraFrameSource`에서 JPEG 프레임을 받고 `BrowserLiveTransport`로 `WS /api/v1/movement/live/stream`에 보냅니다. `MovementScreen`은 캘리브레이션 진행률, 자세 상태와 랜드마크 오버레이를 표시합니다. 브라우저 구현은 `dart:html`을 사용합니다.

실제 영상은 프론트의 카메라 캡처 단계에서만 사용하며 백엔드는 감지 구간을 저장합니다. 동의·수집이 꺼져 있으면 WebSocket이 열리지 않습니다. 데모 실행 방법과 카메라 문제 해결은 [guide.md](../../../../guide.md), API 계약은 [docs/api.md](../../../../docs/api.md)를 참고하세요.
