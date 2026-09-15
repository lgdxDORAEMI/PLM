// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html이 deprecated라고 뜨지만, getUserMedia/canvas 프레임 캡처를
// package:web(JS interop)로 짜는 것보다 훨씬 간단하고 실수할 여지가 적어서
// 그대로 썼다 (2026-09-15, B-4). 실제 브라우저 없이는 이 파일을 실행 검증할
// 수 없으므로, `flutter run -d chrome`으로 반드시 수동 확인이 필요하다.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'camera_frame_source.dart';

/// getUserMedia로 카메라를 열고, `<canvas>`로 주기적으로 프레임을 캡처해
/// JPEG bytes로 내보낸다.
class BrowserCameraFrameSource implements CameraFrameSource {
  BrowserCameraFrameSource({
    this.captureWidth = 640,
    this.captureHeight = 480,
    this.captureInterval = const Duration(milliseconds: 200),
    this.jpegQuality = 0.6,
  }) : viewType = 'plm-movement-camera-${_nextViewId++}' {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) => _video);
  }

  static int _nextViewId = 0;

  final int captureWidth;
  final int captureHeight;
  final Duration captureInterval;
  final double jpegQuality;

  @override
  final String viewType;

  final html.VideoElement _video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true');

  html.MediaStream? _stream;
  html.CanvasElement? _canvas;
  Timer? _timer;
  final StreamController<Uint8List> _controller = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  Future<void> start() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw StateError('이 브라우저는 카메라 접근(getUserMedia)을 지원하지 않습니다.');
    }
    _stream = await mediaDevices.getUserMedia({'video': true});
    _video.srcObject = _stream;
    await _video.onLoadedMetadata.first;
    await _video.play();

    _canvas = html.CanvasElement(width: captureWidth, height: captureHeight);
    _timer = Timer.periodic(captureInterval, (_) {
      unawaited(_captureFrame());
    });
  }

  Future<void> _captureFrame() async {
    final canvas = _canvas;
    if (canvas == null || _controller.isClosed) return;
    final ctx = canvas.context2D;
    ctx.drawImageScaled(_video, 0, 0, captureWidth, captureHeight);
    final blob = await canvas.toBlob('image/jpeg', jpegQuality);
    final bytes = await _blobToBytes(blob);
    if (!_controller.isClosed) {
      _controller.add(bytes);
    }
  }

  Future<Uint8List> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    return (reader.result as ByteBuffer).asUint8List();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _stream?.getTracks().forEach((track) => track.stop());
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
