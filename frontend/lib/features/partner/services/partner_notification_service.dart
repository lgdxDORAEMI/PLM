import '../models/partner_notification.dart';

abstract interface class PartnerNotificationService {
  Future<List<PartnerNotificationItem>> fetchAll();
  Future<bool> hasUnread();
  Future<PartnerNotificationItem> markRead(String id);
}
