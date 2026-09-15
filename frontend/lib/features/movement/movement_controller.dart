import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'camera_frame_source.dart';
import 'live_transport.dart';
import 'models/live_message.dart';
import 'models/posture_frame_state.dart';

enum MovementConnectionState { idle, connecting, calibrating, live, disconnected, error }

/// 카메라 캡처 + `/api/v1/movement/live/stream` WebSocket 연동 상태를 관리한다.
///
/// 이 클래스는 CameraFrameSource/LiveTransport 인터페이스에만 의존하고, 실제
/// dart:html 기반 구현(BrowserCameraFrameSource/BrowserLiveTransport)은 전혀
/// import하지 않는다 — 그래야 이 파일이 순수 Dart VM에서 컴파일/테스트된다.
/// dart:html을 쓰는 파일을 이 파일이 (기본값 등으로) import하는 순간, 이 파일을
/// 쓰는 테스트 전체가 `flutter test --platform chrome`(느리고 이 환경에서는
/// 멈춰버림)이 필요해진다. 실제 브라우저 팩토리 연결은 movement_screen.dart에서
/// 한다.
class MovementController extends ChangeNotifier {
  MovementController({
    required Uri wsUri,
    required CameraFrameSource Function() cameraFrameSourceFactory,
    required Future<LiveTransport> Function(Uri) transportFactory,
  }) : _wsUri = wsUri,
       _cameraFactory = cameraFrameSourceFactory,
       _transportFactory = transportFactory;

  final Uri _wsUri;
  final CameraFrameSource Function() _cameraFactory;
  final Future<LiveTransport> Function(Uri) _transportFactory;

  CameraFrameSource? _camera;
  LiveTransport? _transport;
  StreamSubscription<Uint8List>? _frameSub;
  StreamSubscription<String>? _messageSub;

  MovementConnectionState state = MovementConnectionState.idle;
  int calibrationCollected = 0;
  int calibrationTarget = 0;
  PostureFrameState? latestFrame;
  String? errorMessage;
  bool _disposed = false;

  String? get cameraViewType => _camera?.viewType;

  Future<void> start() async {
    if (state == MovementConnectionState.connecting ||
        state == MovementConnectionState.calibrating ||
        state == MovementConnectionState.live) {
      return;
    }
    errorMessage = null;
    _setState(MovementConnectionState.connecting);

    try {
      final camera = _cameraFactory();
      await camera.start();
      _camera = camera;

      final transport = await _transportFactory(_wsUri);
      _transport = transport;

      _messageSub = transport.messages.listen(_handleMessage, onError: _handleError);
      _frameSub = camera.frames.listen(transport.sendFrame);

      _setState(MovementConnectionState.calibrating);
      unawaited(
        transport.onClose.then((_) {
          if (state != MovementConnectionState.idle && state != MovementConnectionState.error) {
            _setState(MovementConnectionState.disconnected);
          }
        }),
      );
    } catch (e) {
      errorMessage = '$e';
      await _cleanup();
      _setState(MovementConnectionState.error);
    }
  }

  void _handleMessage(String raw) {
    final LiveMessage message;
    try {
      message = LiveMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      _handleError(e);
      return;
    }

    switch (message) {
      case CalibrationProgress(collected: final collected, target: final target):
        calibrationCollected = collected;
        calibrationTarget = target;
        _setState(MovementConnectionState.calibrating);
      case CalibrationDone():
        _setState(MovementConnectionState.live);
      case FrameUpdate(state: final frame):
        // 세션에 이미 저장된 캘리브레이션이 있으면 서버가 캘리브레이션 단계를
        // 통째로 건너뛰고 곧바로 frame을 보낸다 — 그 경우 calibration_done을
        // 절대 못 받으므로, frame이 오면 그 자체로 live 상태임을 보장해야 한다.
        // (실기기 테스트로 발견: 이걸 안 하면 화면이 "캘리브레이션 준비 중"에
        // 갇힌 채로 실제로는 keypoint가 계속 갱신되는 상태가 된다.)
        latestFrame = frame;
        state = MovementConnectionState.live;
        notifyListeners();
    }
  }

  void _handleError(Object error) {
    errorMessage = '$error';
    _setState(MovementConnectionState.error);
  }

  void _setState(MovementConnectionState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  Future<void> stop() async {
    await _cleanup();
    _setState(MovementConnectionState.idle);
  }

  /// 리소스 정리만 한다 (state는 안 건드림) — stop()과 start()의 실패 처리가
  /// 각자 원하는 최종 상태(idle/error)를 정확히 세팅할 수 있게 분리했다.
  /// 원래 stop()이 끝에서 항상 idle로 덮어써서, start() 실패 시 error 상태가
  /// 바로 idle로 사라지는 버그가 있었다 (테스트로 발견, 2026-09-15).
  Future<void> _cleanup() async {
    await _frameSub?.cancel();
    await _messageSub?.cancel();
    await _transport?.close();
    await _camera?.dispose();
    _frameSub = null;
    _messageSub = null;
    _transport = null;
    _camera = null;
    latestFrame = null;
    calibrationCollected = 0;
    calibrationTarget = 0;
  }

  @override
  void dispose() {
    // stop()의 정리 작업(_cleanup)은 비동기라 dispose() 시점엔 안 끝나 있다.
    // _disposed를 먼저 세워서, 정리가 나중에 끝나고 _setState가 notifyListeners를
    // 부르려 할 때 "disposed ChangeNotifier 사용" assertion이 터지지 않게 막는다
    // (dispose()만 직접 호출하는 테스트로 발견, 2026-09-15).
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
