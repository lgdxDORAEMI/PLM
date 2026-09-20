import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../partner/models/partner_request.dart';
import '../models/household_task.dart';
import 'household_request_service.dart';

/// Creates household requests in the family API and keeps their returned state.
class ApiHouseholdRequestService extends ChangeNotifier
    implements HouseholdRequestService {
  ApiHouseholdRequestService({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;
  final Map<String, Map<String, HouseholdRequestProgress>> _progress = {};

  @override
  Future<List<HouseholdTask>> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/household/today',
      throwOnNotFound: true,
    );
    final items = response?['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) {
          final payload = item['payload'] is Map
              ? item['payload'] as Map
              : const <String, dynamic>{};
          final owner = switch (payload['owner']) {
            'partner' => HouseholdTaskOwner.partner,
            'appliance' => HouseholdTaskOwner.appliance,
            _ => HouseholdTaskOwner.self,
          };
          return HouseholdTask(
            id: item['item_id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            description:
                item['description']?.toString() ??
                payload['reason']?.toString() ??
                '',
            owner: owner,
            selected: owner == HouseholdTaskOwner.partner,
            status: item['status'] == 'completed'
                ? HouseholdTaskStatus.done
                : HouseholdTaskStatus.planned,
          );
        })
        .toList(growable: false);
  }

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

  @override
  Future<List<PartnerRequestData>> fetchAll() async {
    final response = await _client.getList('/api/v1/family/household-requests');
    return (response ?? const [])
        .whereType<Map>()
        .map((item) => PartnerRequestData.fromJson(item.cast()))
        .toList(growable: false);
  }

  @override
  Future<PartnerRequestData?> fetchRequest(String requestId) async {
    final response = await _client.get(
      '/api/v1/family/household-requests/${Uri.encodeComponent(requestId)}',
    );
    return response == null ? null : PartnerRequestData.fromJson(response);
  }

  @override
  Future<PartnerRequestData> confirm(String requestId) =>
      _update(requestId, 'confirm');

  @override
  Future<PartnerRequestData> complete(String requestId) =>
      _update(requestId, 'complete');

  Future<PartnerRequestData> _update(String requestId, String action) async {
    final response = await _client.post(
      '/api/v1/family/household-requests/${Uri.encodeComponent(requestId)}/$action',
    );
    if (response == null) throw StateError('가사 요청 응답이 없습니다.');
    return PartnerRequestData.fromJson(response);
  }
}
