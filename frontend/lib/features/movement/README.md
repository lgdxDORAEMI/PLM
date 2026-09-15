# Movement

Flutter Web 카메라로 `WS /api/v1/movement/live/stream`(백엔드 B-1/B-3)에 프레임을 보내고,
캘리브레이션 진행 상황과 실시간 자세/부담 라벨을 보여주는 데모 화면입니다(B-4, 2026-09-15).
데모 전용이며, 실제 서비스 전환 시 재검토 대상입니다(`docs/movement/구현계획서_v3.md` §4 참고).

## 파일 구성

- `models/posture_frame_state.dart`, `models/live_message.dart` — 백엔드
  `backend/app/schemas/movement.py`와 1:1 대응하는 응답 모델(손으로 작성, 코드젠 없음)
- `camera_frame_source.dart`, `live_transport.dart` — 카메라/WebSocket을 각각 인터페이스로
  분리. 실제 구현(`browser_*.dart`)은 `dart:html` 기반이라 브라우저 밖에서 테스트할 수 없어서,
  `MovementController`가 이 인터페이스에만 의존하게 하고 테스트에서는 가짜로 주입한다
  (`test/features/movement/fakes.dart`)
- `browser_camera_frame_source.dart` — getUserMedia로 카메라를 열고 `<canvas>`로 프레임을
  주기적으로(기본 200ms=5fps) JPEG로 인코딩해 내보낸다
- `browser_live_transport.dart` — `dart:html`의 `WebSocket`으로 서버와 통신
- `movement_controller.dart` — 카메라 캡처 ↔ WebSocket 송수신 ↔ 상태(연결중/캘리브레이션/
  실시간판정/에러) 관리
- `movement_overlay_painter.dart` — 캡처 프레임 좌표계의 landmark를 실제 위젯 크기로
  스케일링해서 그리는 `CustomPainter`
- `movement_screen.dart` — 위 전부를 붙인 화면. 지금은 `app.dart`에 임시 버튼("모션 인식
  데모 보기")으로만 연결되어 있다 — 다른 기능 화면이 하나도 없어서(features/* 전부
  미구현) 실제 네비게이션이 생기면 그 안으로 옮겨야 한다

## 왜 `dart:html`인가

`package:web` + `js_interop`이 현재 권장되는 방식이지만(`dart:html`은 deprecated info 경고),
getUserMedia/canvas 프레임 캡처를 `dart:html`로 짜는 게 훨씬 간단하고 실수할 여지가 적어서
이걸 선택했다. 실제 브라우저 없이는 이 상호작용을 실행 검증할 수 없었기 때문에, 검증
가능성을 위해 더 단순한 API를 우선했다. `analysis_options.yaml`을 건드리지 않고 각 파일
상단에 `ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter`로만
경고를 억제했다.

## 테스트 관련 주의사항

`dart:html`을 쓰는 파일이 있어서 **`flutter test`(기본, Dart VM)로는 컴파일이 안 된다.**
`flutter test --platform chrome`으로 실행해야 한다. 모델 파싱 테스트와 `MovementController`
테스트(가짜 카메라/WebSocket 주입)는 이 방식으로 자동 검증했지만, **실제 getUserMedia
호출·캔버스 캡처·실제 WebSocket 연결 자체는 사람이 `flutter run -d chrome`으로 직접
확인해야 한다** — 이 리포지토리 환경에는 카메라가 없어서 이 부분은 검증하지 못했다.

## 확인이 필요한 것 (다음에 할 일)

- 실제 브라우저에서 카메라 권한 프롬프트 → 캘리브레이션 → 실시간 오버레이가 정상 동작하는지
- 백엔드 WebSocket의 Origin 검증이 없다는 점(`docs/api.md` 참고) — 데모는 문제없지만 실서비스
  전환 시 반드시 손봐야 함
- 프레임 전송 주기(200ms)/해상도(640x480)/JPEG 품질(0.6)의 실제 튜닝 (B-7b)
