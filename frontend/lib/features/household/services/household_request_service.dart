import 'package:flutter/foundation.dart';

enum HouseholdRequestProgress { requested, confirmed, completed }

class HouseholdShareResult {
  const HouseholdShareResult({required this.requestId});

  final String requestId;
}

/// Household UI가 파트너 화면의 저장 방식이나 API 계약에 직접 의존하지 않게 한다.
abstract interface class HouseholdRequestService implements Listenable {
  Future<HouseholdShareResult> send({
    required List<String> tasks,
    required String reason,
    required String supportingInfo,
  });

  HouseholdRequestProgress? progressForTask(String requestId, String taskTitle);
}
