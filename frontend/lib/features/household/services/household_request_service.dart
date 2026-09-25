import 'package:flutter/foundation.dart';

import '../../partner/models/partner_request.dart';
import '../models/household_task.dart';

enum HouseholdRequestProgress { requested, confirmed, completed }

class HouseholdShareResult {
  const HouseholdShareResult({required this.requestId});

  final String requestId;
}

/// Household UI가 파트너 화면의 저장 방식이나 API 계약에 직접 의존하지 않게 한다.
abstract interface class HouseholdRequestService implements Listenable {
  Future<List<HouseholdTask>> fetchGuide();

  Future<HouseholdShareResult> send({
    required List<HouseholdTask> tasks,
    required String reason,
    required String supportingInfo,
  });

  HouseholdRequestProgress? progressForTask(String requestId, String taskId);

  /// [date]를 주면 그 날짜의 요청만 받는다(서버 필터). 가사 가이드는 오늘 것만 쓴다.
  Future<List<PartnerRequestData>> fetchAll({DateTime? date});
  Future<PartnerRequestData?> fetchRequest(String requestId);
  Future<PartnerRequestData> confirm(String requestId, String itemId);
  Future<PartnerRequestData> complete(String requestId, String itemId);
}
