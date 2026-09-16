import 'package:flutter/foundation.dart';

import '../models/partner_request.dart';

class PartnerRequestStore extends ChangeNotifier {
  PartnerRequestStore._();

  static final PartnerRequestStore instance = PartnerRequestStore._();
  final Map<String, PartnerRequestData> _requests = {};

  PartnerRequestData request(String id) => _requests.putIfAbsent(
    id,
    () => PartnerRequestData(
      id: id,
      requester: '희선님',
      reason: '오늘은 허리 통증이 있어 무거운 물건을 들지 않는 게 좋아요.',
      tasks: const ['장보기 · 무거운 것 옮기기', '식탁 위 정리'],
      supportingInfo: '장보기 목록 · 생수, 현미, 무가당 요거트',
    ),
  );

  void save(PartnerRequestData value) {
    _requests[value.id] = value;
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
