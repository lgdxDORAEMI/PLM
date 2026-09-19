import '../../../core/network/api_client.dart';
import '../models/partner_notification.dart';
import 'partner_notification_service.dart';

class ApiPartnerNotificationService implements PartnerNotificationService {
  ApiPartnerNotificationService({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<PartnerNotificationItem>> fetchAll() async {
    final response = await _client.getList('/api/v1/family/notifications');
    return (response ?? const [])
        .whereType<Map>()
        .map((item) => PartnerNotificationItem.fromJson(item.cast()))
        .toList(growable: false);
  }

  @override
  Future<PartnerNotificationItem> markRead(String id) async {
    final response = await _client.post(
      '/api/v1/family/notifications/${Uri.encodeComponent(id)}/read',
    );
    if (response == null) throw StateError('알림 응답이 없습니다.');
    return PartnerNotificationItem.fromJson(response);
  }
}
