import 'package:flutter/foundation.dart';

import '../models/partner_request.dart';

class PartnerRequestStore extends ChangeNotifier {
  PartnerRequestStore._();

  static final PartnerRequestStore instance = PartnerRequestStore._();
  final Map<String, PartnerRequestData> _requests = {};

  Iterable<PartnerRequestData> get requests => _requests.values;

  PartnerRequestData request(String id) => _requests.putIfAbsent(
    id,
    () => PartnerRequestData(
      id: id,
      requester: '희선님',
      reason: '오늘은 허리 통증이 있어 무거운 물건을 들지 않는 게 좋아요.',
      tasks: const [
        PartnerRequestTask(
          id: 'heavy-grocery',
          title: '장보기 · 무거운 것 옮기기',
          description: '쌀, 생수 등 5kg 이상 품목이 포함돼 있어요.',
        ),
        PartnerRequestTask(
          id: 'table-cleanup',
          title: '식탁 위 정리 — 서서 5분',
          description: '서서 하는 동작이라 오래 걸리지 않아요.',
        ),
        PartnerRequestTask(
          id: 'water-plants',
          title: '화분 물주기 — 앉아서 가능',
          description: '앉아서 할 수 있는 가벼운 일이에요.',
        ),
      ],
      supportingInfo: '장보기 목록 · 생수, 현미, 무가당 요거트',
    ),
  );

  void save(PartnerRequestData value) {
    _requests[value.id] = value;
    notifyListeners();
  }

  PartnerRequestSummary? summaryFor(String recordDate) {
    final matching = _requests.values
        .where((request) => request.recordDate == recordDate)
        .toList(growable: false);
    if (matching.isEmpty) return null;
    return PartnerRequestSummary(
      requested: matching.fold(0, (sum, item) => sum + item.tasks.length),
      confirmed: matching.fold(0, (sum, item) => sum + item.confirmedCount),
      completed: matching.fold(0, (sum, item) => sum + item.completedCount),
    );
  }

  void clear() {
    _requests.clear();
    notifyListeners();
  }
}

class PartnerRequestSummary {
  const PartnerRequestSummary({
    required this.requested,
    required this.confirmed,
    required this.completed,
  });

  final int requested;
  final int confirmed;
  final int completed;
}
