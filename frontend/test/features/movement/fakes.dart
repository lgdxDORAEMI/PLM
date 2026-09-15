import 'dart:async';
import 'dart:typed_data';

import 'package:plm_frontend/features/movement/camera_frame_source.dart';
import 'package:plm_frontend/features/movement/live_transport.dart';

/// 브라우저 없이 MovementController를 테스트하기 위한 가짜 카메라.
/// 실제로는 아무것도 캡처하지 않고, 테스트가 emitFrame()으로 프레임을 흘려보낸다.
class FakeCameraFrameSource implements CameraFrameSource {
  final StreamController<Uint8List> _controller = StreamController<Uint8List>.broadcast();
  bool started = false;
  bool disposed = false;

  @override
  String? get viewType => 'fake-view-type';

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  void emitFrame(Uint8List bytes) => _controller.add(bytes);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

/// 브라우저 없이 MovementController를 테스트하기 위한 가짜 WebSocket.
/// 테스트가 emitMessage()로 서버가 보낸 것처럼 메시지를 흘려보내고,
/// sentFrames로 클라이언트가 보낸 프레임을 확인할 수 있다.
class FakeLiveTransport implements LiveTransport {
  final StreamController<String> _messages = StreamController<String>.broadcast();
  final Completer<void> _closeCompleter = Completer<void>();
  final List<Uint8List> sentFrames = [];
  bool closed = false;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  void emitMessage(String json) => _messages.add(json);

  void simulateServerClose() {
    if (!_closeCompleter.isCompleted) _closeCompleter.complete();
  }

  @override
  void sendFrame(Uint8List jpegBytes) => sentFrames.add(jpegBytes);

  @override
  Future<void> close() async {
    closed = true;
    await _messages.close();
    simulateServerClose();
  }
}
