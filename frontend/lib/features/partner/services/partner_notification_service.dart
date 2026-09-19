import '../models/partner_notification.dart';

abstract interface class PartnerNotificationService {
  Future<List<PartnerNotificationItem>> fetchAll();
  Future<PartnerNotificationItem> markRead(String id);
}
