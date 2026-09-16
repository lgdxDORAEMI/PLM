import 'package:flutter/foundation.dart';

import '../models/movement_alert.dart';

class RealtimeAlertController extends ChangeNotifier {
  bool _mockPreviewActive = true;
  final Set<String> _reviewedAlertIds = {};

  bool get mockPreviewActive => _mockPreviewActive;
  List<MovementAlert> get alerts => MovementMockData.alerts;
  List<MovementAlert> get todayAlerts =>
      alerts.where((alert) => alert.isToday).toList(growable: false);
  MovementAlert? get latestEvent => todayAlerts.firstOrNull;
  MovementDeviceState get deviceState => MovementMockData.device;
  bool isReviewed(String id) => _reviewedAlertIds.contains(id);

  /// 실제 감지 장치를 제어하지 않고 화면의 Mock 현재 상태만 전환한다.
  void setMockPreview(bool value) {
    if (_mockPreviewActive == value) return;
    _mockPreviewActive = value;
    notifyListeners();
  }

  /// 확인 상태는 서버 전송 없이 현재 앱 세션에서만 유지한다.
  void acknowledge(String id) {
    if (_reviewedAlertIds.add(id)) notifyListeners();
  }
}
