// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// browser_camera_frame_source.dart와 같은 이유로 dart:html의 WebSocket을 썼다.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'live_transport.dart';

class BrowserLiveTransport implements LiveTransport {
  BrowserLiveTransport._(this._socket);

  final html.WebSocket _socket;
  final Completer<void> _closeCompleter = Completer<void>();

  static Future<BrowserLiveTransport> connect(Uri uri) async {
    final socket = html.WebSocket(uri.toString());
    final transport = BrowserLiveTransport._(socket);

    final openOrError = Completer<void>();
    socket.onOpen.first.then((_) {
      if (!openOrError.isCompleted) openOrError.complete();
    });
    socket.onError.first.then((event) {
      if (!openOrError.isCompleted) {
        openOrError.completeError(StateError('WebSocket 연결 실패: $event'));
      }
    });
    socket.onClose.first.then((_) {
      if (!transport._closeCompleter.isCompleted) {
        transport._closeCompleter.complete();
      }
    });

    await openOrError.future;
    return transport;
  }

  @override
  Stream<String> get messages =>
      _socket.onMessage.map((event) => event.data as String);

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void sendFrame(Uint8List jpegBytes) {
    _socket.send(jpegBytes);
  }

  @override
  Future<void> close() async {
    if (_socket.readyState == html.WebSocket.OPEN) {
      _socket.close();
    }
    await onClose;
  }
}
