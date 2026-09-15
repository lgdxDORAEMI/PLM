import 'dart:typed_data';

/// `/api/v1/movement/live/stream` WebSocket 연결 하나를 추상화한다.
///
/// 실제 구현(BrowserLiveTransport, dart:html WebSocket 기반)은 브라우저 없이
/// 테스트할 수 없어서, MovementController가 이 인터페이스로만 의존하게 했다.
abstract class LiveTransport {
  /// 서버가 보낸 원문 텍스트(JSON) 메시지 스트림.
  Stream<String> get messages;

  /// 연결이 끊겼을 때(정상/비정상 모두) 완료되는 Future.
  Future<void> get onClose;

  /// JPEG로 인코딩된 프레임 하나를 서버로 보낸다.
  void sendFrame(Uint8List jpegBytes);

  Future<void> close();
}
