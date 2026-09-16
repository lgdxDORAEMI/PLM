import '../../partner/data/partner_request_store.dart';
import '../../partner/data/partner_notification_store.dart';
import '../../partner/models/partner_notification.dart';
import '../../partner/models/partner_request.dart';
import 'household_request_service.dart';

class MockHouseholdRequestService implements HouseholdRequestService {
  MockHouseholdRequestService({PartnerRequestStore? store})
    : _store = store ?? PartnerRequestStore.instance;

  final PartnerRequestStore _store;
  static int _sequence = 0;

  @override
  void addListener(void Function() listener) => _store.addListener(listener);

  @override
  void removeListener(void Function() listener) =>
      _store.removeListener(listener);

  @override
  Future<HouseholdShareResult> send({
    required List<String> tasks,
    required String reason,
    required String supportingInfo,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final requestId = 'household-request-${++_sequence}';
    final request = PartnerRequestData(
      id: requestId,
      requester: '희선님',
      reason: reason,
      tasks: List.unmodifiable([
        for (var index = 0; index < tasks.length; index += 1)
          PartnerRequestTask(id: '$requestId-task-$index', title: tasks[index]),
      ]),
      supportingInfo: supportingInfo,
    );
    _store.save(request);
    PartnerNotificationStore.instance.add(
      PartnerNotificationItem(
        id: 'request-$requestId',
        type: PartnerNotificationType.householdRequest,
        title: '가사 요청이 도착했어요',
        message: tasks.length == 1
            ? tasks.first
            : '${tasks.first} 외 ${tasks.length - 1}건',
        timeLabel: '방금',
        requestId: requestId,
      ),
    );
    return HouseholdShareResult(requestId: requestId);
  }

  @override
  HouseholdRequestProgress? progressFor(String requestId) {
    final request = _store.request(requestId);
    return switch (request.status) {
      PartnerRequestStatus.requested => HouseholdRequestProgress.requested,
      PartnerRequestStatus.confirmed => HouseholdRequestProgress.confirmed,
      PartnerRequestStatus.completed => HouseholdRequestProgress.completed,
    };
  }
}
