import 'dart:typed_data';

/// 카메라에서 JPEG로 인코딩된 프레임을 주기적으로 내보내는 소스.
///
/// 실제 구현(BrowserCameraFrameSource, dart:html 기반)은 브라우저 없이 테스트할
/// 수 없어서, MovementController가 이 인터페이스로만 의존하게 해서 위젯/컨트롤러
/// 테스트에서는 가짜 구현을 주입할 수 있게 했다.
abstract class CameraFrameSource {
  /// `HtmlElementView(viewType: ...)`로 미리보기를 붙일 때 쓴다. 브라우저 밖
  /// (테스트에서 주입하는 가짜 구현)에서는 null이어도 된다.
  String? get viewType;

  /// JPEG bytes 스트림. 매 프레임(캡처 간격)마다 하나씩 나온다.
  Stream<Uint8List> get frames;

  /// 카메라를 켜고 캡처를 시작한다. frames를 구독하기 전에 호출한다.
  Future<void> start();

  /// 카메라를 끄고 리소스를 정리한다.
  Future<void> dispose();
}
