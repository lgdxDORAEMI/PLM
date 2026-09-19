import '../data/partner_notification_store.dart';
import '../models/partner_notification.dart';
import 'partner_notification_service.dart';

class MockPartnerNotificationService implements PartnerNotificationService {
  const MockPartnerNotificationService({this.store});

  final PartnerNotificationStore? store;
  PartnerNotificationStore get _store =>
      store ?? PartnerNotificationStore.instance;

  @override
  Future<List<PartnerNotificationItem>> fetchAll() async => _store.items;

  @override
  Future<PartnerNotificationItem> markRead(String id) async {
    _store.markRead(id);
    return _store.items.firstWhere((item) => item.id == id);
  }
}
