import '../../../core/network/api_client.dart';
import '../models/movement_alert.dart';
import 'movement_dashboard_service.dart';

class ApiMovementDashboardService implements MovementDashboardService {
  ApiMovementDashboardService({ApiClient? client, this.includePrivacy = true})
    : _client = client ?? ApiClient();

  final ApiClient _client;
  final bool includePrivacy;

  @override
  Future<MovementDashboardData> fetch() async {
    final responses = await Future.wait<Object?>([
      _client.getList('/api/v1/movement/events'),
      _client.get('/api/v1/movement/report/daily'),
      includePrivacy
          ? _client.get('/api/v1/family/motion/privacy')
          : Future<Map<String, dynamic>?>.value(),
    ]);
    final events = responses[0] as List<dynamic>? ?? const [];
    final report = responses[1] as Map<String, dynamic>?;
    final privacy = responses[2] as Map<String, dynamic>?;
    return MovementDashboardData(
      alerts: events
          .whereType<Map>()
          .map((item) => MovementAlert.fromJson(item.cast()))
          .toList(growable: false),
      forwardBendSeconds:
          (report?['cumulative_forward_bend_sec'] as num?)?.toDouble() ?? 0,
      burdenEventCount:
          (report?['bending_burden_event_count'] as num?)?.toInt() ?? 0,
      narratives:
          (report?['narratives'] as List?)?.whereType<String>().toList() ??
          const [],
      consentGranted: privacy?['consent_granted'] == true,
      collectionEnabled: privacy?['collection_enabled'] == true,
    );
  }
}
