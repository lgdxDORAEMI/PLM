import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/controllers/realtime_alert_controller.dart';
import 'package:plm_frontend/features/movement/services/mock_movement_dashboard_service.dart';

void main() {
  test('오늘 감지 로그를 제공한다', () async {
    final controller = RealtimeAlertController(
      service: const MockMovementDashboardService(),
    );
    await controller.load();
    expect(controller.todayAlerts, hasLength(5));
    expect(controller.todayAlerts.first.id, 'back-load');
  });
}
