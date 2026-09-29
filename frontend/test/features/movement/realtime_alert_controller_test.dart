import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/movement/models/movement_alert.dart';
import 'package:plm_frontend/features/movement/services/movement_dashboard_service.dart';
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

  test('아내가 공개하기 전 403은 notShared다(09-29)', () async {
    final controller = RealtimeAlertController(service: _NotSharedService());
    await controller.load();
    expect(controller.state, MovementDashboardViewState.notShared);
  });
}

class _NotSharedService implements MovementDashboardService {
  @override
  Future<MovementDashboardData> fetch() async =>
      throw ApiException(403, ApiException.partnerNotSharedDetail);
}
