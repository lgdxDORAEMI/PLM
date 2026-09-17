import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/controllers/realtime_alert_controller.dart';

void main() {
  test('수집을 꺼도 오늘 감지 로그는 유지한다', () {
    final controller = RealtimeAlertController();
    final existingAlerts = controller.todayAlerts;
    expect(controller.detectionEnabled, isTrue);
    expect(existingAlerts, hasLength(3));
    expect(controller.latestEvent?.id, 'back-load');

    controller.setDetectionEnabled(false);

    expect(controller.detectionEnabled, isFalse);
    expect(controller.todayAlerts, existingAlerts);
  });
}
