import '../models/movement_alert.dart';

abstract interface class MovementDashboardService {
  Future<MovementDashboardData> fetch();
}
