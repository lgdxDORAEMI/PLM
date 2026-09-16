import 'package:flutter/foundation.dart';

import '../data/partner_notification_store.dart';
import '../models/partner_notification.dart';

class PartnerNotificationController extends ChangeNotifier {
  PartnerNotificationController({PartnerNotificationStore? store})
    : store = store ?? PartnerNotificationStore.instance {
    this.store.addListener(_sync);
  }

  final PartnerNotificationStore store;

  List<PartnerNotificationItem> get items => store.items;
  int get unreadCount => store.unreadCount;

  void markRead(String id) => store.markRead(id);

  void markAllRead() => store.markAllRead();

  void _sync() => notifyListeners();

  @override
  void dispose() {
    store.removeListener(_sync);
    super.dispose();
  }
}
