// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html이 deprecated라고 뜨지만, getUserMedia/canvas 프레임 캡처를
// package:web(JS interop)로 짜는 것보다 훨씬 간단하고 실수할 여지가 적어서
// 그대로 썼다 (2026-09-15, B-4). 실제 브라우저 없이는 이 파일을 실행 검증할
// 수 없으므로, `flutter run -d chrome`으로 반드시 수동 확인이 필요하다.

import 'dart:async';
import 'dart:convert';
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
    this.deviceId,
  }) : viewType = 'plm-movement-camera-${_nextViewId++}' {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int _) => _video,
    );
  }

  static int _nextViewId = 0;

  final int captureWidth;
  final int captureHeight;
  final Duration captureInterval;
  final double jpegQuality;

  /// 내장 웹캠과 외장 카메라가 함께 연결된 환경에서 브라우저 기본값이 엉뚱한
  /// 장치를 잡는 걸 막기 위한 명시적 선택. null이면 브라우저 기본 동작.
  final String? deviceId;

  @override
  final String viewType;

  // drawImageScaled()가 원본 비율과 무관하게 항상 captureWidth x captureHeight로
  // "늘려서" 캡처하므로, 화면에 보이는 미리보기도 브라우저 기본 동작(원본 비율
  // 유지)이 아니라 똑같이 늘려서 보여줘야 keypoint 위치가 화면과 어긋나지
  // 않는다 (실기기 테스트로 발견, 2026-09-15).
  final html.VideoElement _video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.setProperty('object-fit', 'fill');

  html.MediaStream? _stream;
  html.CanvasElement? _canvas;
  Timer? _timer;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  Future<void> start() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw StateError('이 브라우저는 카메라 접근(getUserMedia)을 지원하지 않습니다.');
    }
    _stream = await mediaDevices.getUserMedia({
      'video': deviceId == null
          ? true
          : {
              'deviceId': {'exact': deviceId},
            },
    });
    _video.srcObject = _stream;
    await _video.onLoadedMetadata.first;
    await _video.play();

    _canvas = html.CanvasElement(width: captureWidth, height: captureHeight);
    _timer = Timer.periodic(captureInterval, (_) => _captureFrame());
  }

  // toBlob()+FileReader(비동기 콜백 체인)는 브라우저 없이 짠 코드라 실제로
  // 동작하는지 검증 못 했고, 실제로 캘리브레이션이 멈추는 원인이 됐다(2026-09-15
  // 실기기 테스트로 발견). toDataUrl()은 훨씬 오래되고 단순한 동기 API라 이걸로
  // 바꿨다 — 캔버스를 base64 JPEG 문자열로 바로 뽑아서 디코딩만 하면 된다.
  void _captureFrame() {
    final canvas = _canvas;
    if (canvas == null || _controller.isClosed) return;
    final ctx = canvas.context2D;
    ctx.drawImageScaled(_video, 0, 0, captureWidth, captureHeight);
    final dataUrl = canvas.toDataUrl('image/jpeg', jpegQuality);
    final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
    if (!_controller.isClosed) {
      _controller.add(bytes);
    }
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
