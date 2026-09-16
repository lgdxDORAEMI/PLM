# Movement

## 제품 화면과 기술 데모 경계

`ProductMovementScreen`은 B-MOTION-001의 Phase 2 화면 구성을 확인하기 위한 Local Mock입니다. `/wife/movement`는 Wife 하단 실시간 탭, `/partner/movement`는 Partner Calendar CTA에서만 진입하며, 제품 화면은 카메라 권한·MediaPipe·WebSocket·실시간 센서를 사용하지 않습니다.

아래 카메라/분석 구현은 `main_movement_debug.dart`로만 실행하는 독립 기술 데모입니다. 일반 `main.dart`와 `AppRouter`에서는 `MovementScreen`, `BrowserCameraFrameSource`, `BrowserLiveTransport`를 생성하지 않습니다.

Flutter Web 카메라로 `WS /api/v1/movement/live/stream`(백엔드 B-1/B-3)에 프레임을 보내고,
캘리브레이션 진행 상황과 실시간 자세/부담 라벨을 보여주는 데모 화면입니다(B-4, 2026-09-15).
데모 전용이며, 실제 서비스 전환 시 재검토 대상입니다(`docs/movement/구현계획서_v3.md` §3 참고).

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
  미구현) 실제 네비게이션이 생기면 그 안으로 옮겨야 한다. `cameraFrameSourceFactory`/
  `transportFactory`가 필수 생성자 파라미터다 — 실제로 쓸 때는 `BrowserCameraFrameSource.new`/
  `BrowserLiveTransport.connect`를 넘겨야 하고(`app.dart` 참고), 테스트에서는
  `test/features/movement/fakes.dart`의 가짜를 넘긴다

## 왜 `dart:html`인가

`package:web` + `js_interop`이 현재 권장되는 방식이지만(`dart:html`은 deprecated info 경고),
getUserMedia/canvas 프레임 캡처를 `dart:html`로 짜는 게 훨씬 간단하고 실수할 여지가 적어서
이걸 선택했다. 실제 브라우저 없이는 이 상호작용을 실행 검증할 수 없었기 때문에, 검증
가능성을 위해 더 단순한 API를 우선했다. `analysis_options.yaml`을 건드리지 않고 각 파일
상단에 `ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter`로만
경고를 억제했다.

## 테스트 관련 주의사항

`browser_*.dart`(dart:html 사용)는 `MovementController`뿐 아니라 `MovementScreen`도
기본값으로 참조하지 않도록 분리해뒀다 — 실제 구현 연결은 이제 `app.dart`(MovementScreen을
생성하는 호출부)에서만 한다. 그래서 `movement_controller.dart`/`movement_screen.dart`와
그 테스트는 `dart:html`을 전혀 안 거치고,
**일반 `flutter test`(Dart VM, 수 초)로 그냥 통과한다.** (단, `MovementScreen`을 실제로
"시작" 상태까지 pump하는 위젯 테스트는 불가능하다 — 미리보기가 `HtmlElementView`를 쓰는데
이 위젯 자체가 Flutter Web 전용이라 VM에서 빌드하면 `UnimplementedError`가 난다. 그래서
`movement_screen.dart`의 동작(특히 백그라운드 전환 시 카메라 정리)은 `flutter run -d chrome`
수동 확인으로만 검증했다.) `flutter test --platform chrome`은
필요 없다 — 실제로 이 환경에서 그 명령이 멈춰서(헤드리스 Chrome 컴파일+실행이 오래 걸리거나
멈춤) 이 구조로 바꿨다. `browser_*.dart` 자체(실제 getUserMedia 호출, 캔버스 캡처, 실제
WebSocket 연결)는 여전히 브라우저 밖에서 검증할 수 없어서 `flutter run -d chrome`으로
사람이 직접 확인해야 한다.

## 실기기 테스트로 발견/수정한 것 (2026-09-15)

- **Navigator 버그**: `app.dart`의 임시 버튼이 `MaterialApp`보다 바깥쪽 `context`로
  `Navigator.of(context)`를 호출해서 클릭해도 아무 반응이 없었다. `Builder`로 감싸서
  `MaterialApp` 안쪽 context를 쓰도록 고쳤다.
- **"캘리브레이션 준비 중..."에서 멈추는 진짜 원인**: 처음엔 `canvas.toBlob()` +
  `FileReader`(비동기 콜백 체인) 캡처가 실패하는 줄 알고 `canvas.toDataUrl()`(동기, base64)로
  바꿨는데, 실제 원인은 따로 있었다 — **세션에 이전에 저장된 캘리브레이션 프로필이 있으면
  서버가 캘리브레이션 단계를 통째로 건너뛰고 곧바로 `frame`을 보내는데, `MovementController`가
  `calibration_done` 없이 `frame`만 오는 경우를 처리하지 못해 상태를 계속 `calibrating`으로
  들고 있었다.** `frame` 수신 자체를 `live` 전환 신호로 처리하도록 고쳤다(테스트로 회귀 방지
  추가). `toDataUrl()` 변경 자체는 더 단순하고 검증하기 쉬운 API라 유지했지만, 이 증상의
  직접 원인은 아니었다.
- **keypoint가 신체 부위와 어긋나 보이는 문제**: `drawImageScaled()`가 원본 카메라 비율과
  무관하게 항상 캡처 해상도(640×480)로 "늘려서" 캡처하는데, 화면에 보이는 `<video>`는 브라우저
  기본 동작(원본 비율 유지, letterbox)으로 그려지고 있어서 캡처된 이미지와 화면에 보이는
  이미지의 비율이 서로 달랐다. 미리보기도 `object-fit: fill`로 똑같이 늘려서 그리도록 맞췄다.

## 확인이 필요한 것 (다음에 할 일)

- **실제 하단 탭(`IndexedStack` 등) 도입 시 카메라 정리 로직 보강 필요**: 지금
  `movement_screen.dart`의 `WidgetsBindingObserver`는 브라우저 탭 전환/창 최소화(웹)·앱
  백그라운드 전환(모바일) 같은 OS·브라우저 레벨 이탈만 감지해서 카메라를 끈다(`AppLifecycleState`
  변화 기반). 지금은 이 화면이 `Navigator.push`로만 접근되는 단일 데모 화면이라 앱 내부에서
  다른 화면으로 이동하면 위젯이 dispose되면서 `stop()`이 자연히 호출되지만, 나중에
  `IndexedStack` 기반 실제 "실시간" 탭이 생기면 탭만 전환해도(위젯은 dispose 안 되고
  `AppLifecycleState`도 안 바뀜) 카메라가 계속 켜진 채로 남는다. 그 탭 구조를 만드는 시점에
  탭 비활성화를 감지해 `controller.stop()`을 명시적으로 호출하는 로직을 추가해야 한다.
- ~~캘리브레이션 진행률이 실제로 올라가고 완료되는지~~, ~~keypoint가 신체 부위에 맞게 그려지는지~~
  — 실기기 재확인 완료(2026-09-15). 측면 자세에서 Standing/Bending이 Unknown으로 잡히는 것만
  남아있었는데, `features.py`의 가시성 가중평균 수정으로 해결(같은 날 커밋)
- ~~백엔드 WebSocket의 Origin 검증이 없다는 점~~ — 해결(2026-09-15, `docs/api.md` 참고).
  로컬 데모(`localhost`)는 그대로 동작하고, 다른 origin에서의 연결 시도만 막힘
- ~~`--release` 모드에서 버벅거림이 나아지는지~~ — 실기기 확인 완료(2026-09-15). 측면 자세
  판정 외에는 문제없다고 확인됨. B-7b(전송 파라미터 튜닝)는 필요 시 나중에 진행
- NFR(암호화·동의철회·최소데이터 전달)은 여전히 코드 주석으로만 있음 — Supabase Auth/DB
  연동 시점으로 의도적으로 미룸 (지금 인프라로는 의미 있게 구현할 수 없음)
- 프레임 전송 주기(200ms)/해상도(640x480)/JPEG 품질(0.6)의 실제 튜닝 (B-7b)
