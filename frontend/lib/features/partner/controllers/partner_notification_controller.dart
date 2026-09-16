import 'package:flutter/foundation.dart';

import '../models/partner_notification.dart';

class PartnerNotificationController extends ChangeNotifier {
  PartnerNotificationController()
    : _items = const [
        PartnerNotificationItem(
          id: 'report-2026-09-13',
          type: PartnerNotificationType.morningReport,
          title: '오늘 아침 리포트가 도착했어요',
          message: '희선님은 오늘 허리 통증과 피로가 높아요.',
          timeLabel: '오늘 오전 8:10',
        ),
        PartnerNotificationItem(
          id: 'request-demo-request',
          type: PartnerNotificationType.householdRequest,
          title: '집안일 도움 요청이 왔어요',
          message: '장보기 · 무거운 것 옮기기를 부탁했어요.',
          timeLabel: '오늘 오전 8:22',
        ),
        PartnerNotificationItem(
          id: 'report-2026-09-12',
          type: PartnerNotificationType.morningReport,
          title: '어제 아침 리포트',
          message: '수면 루틴과 가사 분담 요약을 확인해 보세요.',
          timeLabel: '어제 오전 8:05',
          read: true,
        ),
      ];

  List<PartnerNotificationItem> _items;

  List<PartnerNotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => !item.read).length;

  void markRead(String id) {
    _items = [
      for (final item in _items)
        if (item.id == id) item.copyWith(read: true) else item,
    ];
    notifyListeners();
  }

  void markAllRead() {
    _items = [for (final item in _items) item.copyWith(read: true)];
    notifyListeners();
  }
}
