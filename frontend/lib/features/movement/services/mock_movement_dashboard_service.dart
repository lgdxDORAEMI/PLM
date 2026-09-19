import '../models/movement_alert.dart';
import 'movement_dashboard_service.dart';

class MockMovementDashboardService implements MovementDashboardService {
  const MockMovementDashboardService();

  @override
  Future<MovementDashboardData> fetch() async => const MovementDashboardData(
    alerts: MovementMockData.alerts,
    forwardBendSeconds: 2400,
    burdenEventCount: 4,
    narratives: ['Mock 기준으로 반복 부담 행동이 감지됐어요.'],
    consentGranted: true,
    collectionEnabled: true,
  );
}
