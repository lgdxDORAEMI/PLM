import 'package:flutter/foundation.dart';

import '../models/movement_alert.dart';

class RealtimeAlertController extends ChangeNotifier {
  bool _monitoring = true;
  final Set<String> _reviewedAlertIds = {};

  bool get monitoring => _monitoring;
  List<MovementAlert> get alerts => MovementMockData.alerts;
  bool isReviewed(String id) => _reviewedAlertIds.contains(id);

  void setMonitoring(bool value) {
    if (_monitoring == value) return;
    _monitoring = value;
    notifyListeners();
  }

  /// 확인 상태는 서버 전송 없이 현재 앱 세션에서만 유지한다.
  void acknowledge(String id) {
    if (_reviewedAlertIds.add(id)) notifyListeners();
  }
}
