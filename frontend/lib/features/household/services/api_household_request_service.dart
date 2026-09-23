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
  String? applianceConnectionStatus;

  @override
  Future<List<HouseholdTask>> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/household/today',
      throwOnNotFound: true,
    );
    applianceConnectionStatus = response?['appliance_connection_status']
        ?.toString();
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
          final appliances = payload['appliances'];
          final applianceMaps = appliances is List
              ? appliances.whereType<Map>().toList(growable: false)
              : const <Map>[];
          return HouseholdTask(
            id: item['item_id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            description:
                item['description']?.toString() ??
                payload['reason']?.toString() ??
                '',
            owner: owner,
            applianceNames: applianceMaps
                .map((device) => device['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList(growable: false),
            airPurifierDeviceId: applianceMaps
                .firstWhere(
                  (device) => device['device_type'] == 'air_purifier',
                  orElse: () => const {},
                )['device_id']
                ?.toString(),
            selected: owner == HouseholdTaskOwner.partner,
            status: item['status'] == 'completed'
                ? HouseholdTaskStatus.done
                : HouseholdTaskStatus.planned,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<bool> runAirPurifier(String deviceId) async {
    try {
      await _client.post(
        '/api/v1/thinq/devices/${Uri.encodeComponent(deviceId)}/control',
        {'power': 'on'},
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  @override
  Future<HouseholdShareResult> send({
    required List<HouseholdTask> tasks,
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
          {
            'title': task.title,
            'helper_info': supportingInfo,
            'routine_item_id': task.id,
          },
      ],
    });
    final id = response?['request_id']?.toString();
    if (id == null) throw StateError('가사 요청 번호가 없습니다.');
    _progress[id] = {
      for (final task in tasks) task.id: HouseholdRequestProgress.requested,
    };
    notifyListeners();
    return HouseholdShareResult(requestId: id);
  }

  @override
  HouseholdRequestProgress? progressForTask(String requestId, String taskId) =>
      _progress[requestId]?[taskId];

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
  Future<PartnerRequestData> confirm(String requestId, String itemId) =>
      _update(requestId, itemId, 'confirm');

  @override
  Future<PartnerRequestData> complete(String requestId, String itemId) =>
      _update(requestId, itemId, 'complete');

  Future<PartnerRequestData> _update(
    String requestId,
    String itemId,
    String action,
  ) async {
    final response = await _client.post(
      '/api/v1/family/household-requests/${Uri.encodeComponent(requestId)}'
      '/items/${Uri.encodeComponent(itemId)}/$action',
    );
    if (response == null) throw StateError('가사 요청 응답이 없습니다.');
    return PartnerRequestData.fromJson(response);
  }
}
