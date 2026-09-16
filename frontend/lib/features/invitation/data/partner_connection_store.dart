import 'package:flutter/foundation.dart';

/// 실제 계정 연동 API 전까지 Menu와 Partner Join이 공유하는 로컬 상태다.
class PartnerConnectionStore extends ChangeNotifier {
  PartnerConnectionStore._();

  static final PartnerConnectionStore instance = PartnerConnectionStore._();

  bool _isLinked = false;
  bool get isLinked => _isLinked;

  void markLinked() {
    if (_isLinked) return;
    _isLinked = true;
    notifyListeners();
  }

  void reset() {
    if (!_isLinked) return;
    _isLinked = false;
    notifyListeners();
  }
}
