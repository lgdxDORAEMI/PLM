import 'package:flutter/foundation.dart';

import '../models/movement_alert.dart';

class RealtimeAlertController extends ChangeNotifier {
  bool _detectionEnabled = true;

  bool get detectionEnabled => _detectionEnabled;
  List<MovementAlert> get alerts => MovementMockData.alerts;
  List<MovementAlert> get todayAlerts => alerts;

  /// API 연결 전에도 수집 ON/OFF와 기존 로그 보존 규칙을 같은 상태로 표현한다.
  void setDetectionEnabled(bool value) {
    if (_detectionEnabled == value) return;
    _detectionEnabled = value;
    notifyListeners();
  }
}
