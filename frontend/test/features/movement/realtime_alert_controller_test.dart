import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/controllers/realtime_alert_controller.dart';

void main() {
  test('감지와 알림 확인 상태를 local state로 변경한다', () {
    final controller = RealtimeAlertController();
    expect(controller.monitoring, isTrue);
    expect(controller.isReviewed('back-load'), isFalse);

    controller.setMonitoring(false);
    controller.acknowledge('back-load');

    expect(controller.monitoring, isFalse);
    expect(controller.isReviewed('back-load'), isTrue);
  });
}
