import '../models/movement_alert.dart';

class RealtimeAlertController {
  List<MovementAlert> get alerts => MovementMockData.alerts;
  List<MovementAlert> get todayAlerts => alerts;
}
