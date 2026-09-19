import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'household_request_service.dart';

/// Creates household requests in the family API and keeps their returned state.
class ApiHouseholdRequestService extends ChangeNotifier
    implements HouseholdRequestService {
  ApiHouseholdRequestService({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;
  final Map<String, Map<String, HouseholdRequestProgress>> _progress = {};

  @override
  Future<HouseholdShareResult> send({
    required List<String> tasks,
    required String reason,
    required String supportingInfo,
  }) async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final response = await _client.post('/api/v1/family/household-requests', {
      'target_date': date,
      'reason': reason,
      'items': [
        for (final task in tasks)
          {'title': task, 'helper_info': supportingInfo},
      ],
    });
    final id = response?['request_id']?.toString();
    if (id == null) throw StateError('가사 요청 번호가 없습니다.');
    _progress[id] = {
      for (final task in tasks) task: HouseholdRequestProgress.requested,
    };
    notifyListeners();
    return HouseholdShareResult(requestId: id);
  }

  @override
  HouseholdRequestProgress? progressForTask(
    String requestId,
    String taskTitle,
  ) => _progress[requestId]?[taskTitle];
}
