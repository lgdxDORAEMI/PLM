import 'package:flutter/foundation.dart';

import '../models/partner_notification.dart';

/// Partner 알림의 읽음 상태와 실제 상세 목적지를 Route 전환 사이에 보존한다.
class PartnerNotificationStore extends ChangeNotifier {
  PartnerNotificationStore._() : _items = _initialItems();

  static final PartnerNotificationStore instance = PartnerNotificationStore._();

  List<PartnerNotificationItem> _items;

  List<PartnerNotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => !item.read).length;

  void add(PartnerNotificationItem item) {
    _items = [item, ..._items.where((existing) => existing.id != item.id)];
    notifyListeners();
  }

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

  void reset() {
    _items = _initialItems();
    notifyListeners();
  }

  static List<PartnerNotificationItem> _initialItems() => const [
    PartnerNotificationItem(
      id: 'report-2026-09-13',
      type: PartnerNotificationType.morningReport,
      title: '오늘 아침 리포트가 도착했어요',
      message: '희선님은 오늘 허리 통증과 피로가 높아요.',
      timeLabel: '오늘 오전 8:10',
      reportDate: '2026-09-13',
    ),
    PartnerNotificationItem(
      id: 'request-demo-request',
      type: PartnerNotificationType.householdRequest,
      title: '가사 요청이 도착했어요',
      message: '장보기 · 무거운 것 옮기기 외 2건',
      timeLabel: '오늘 오전 8:22',
      reportDate: '2026-09-13',
      requestId: 'demo-request',
    ),
    PartnerNotificationItem(
      id: 'routine-2026-09-13',
      type: PartnerNotificationType.routineChanged,
      title: '오늘 루틴이 변경됐어요',
      message: '컨디션 변경에 따라 식사·가사 가이드가 조정됐어요.',
      timeLabel: '오늘 오전 9:05',
      reportDate: '2026-09-13',
    ),
    PartnerNotificationItem(
      id: 'report-2026-09-12',
      type: PartnerNotificationType.morningReport,
      title: '어제 아침 리포트',
      message: '수면 루틴과 가사 분담 요약을 확인해 보세요.',
      timeLabel: '어제 오전 8:05',
      reportDate: '2026-09-12',
      read: true,
    ),
  ];
}
