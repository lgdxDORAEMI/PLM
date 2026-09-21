import '../../partner/data/partner_request_store.dart';
import '../../partner/data/partner_notification_store.dart';
import '../../partner/models/partner_notification.dart';
import '../../partner/models/partner_request.dart';
import '../models/household_task.dart';
import 'household_request_service.dart';

class MockHouseholdRequestService implements HouseholdRequestService {
  MockHouseholdRequestService({PartnerRequestStore? store})
    : _store = store ?? PartnerRequestStore.instance;

  final PartnerRequestStore _store;
  static int _sequence = 0;

  @override
  Future<List<HouseholdTask>> fetchGuide() async => HouseholdTaskMockData.tasks;

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
  HouseholdRequestProgress? progressForTask(
    String requestId,
    String taskTitle,
  ) {
    final request = _store.request(requestId);
    final matching = request.tasks.where((task) => task.title == taskTitle);
    if (matching.isEmpty) return null;
    return switch (matching.first.status) {
      PartnerRequestStatus.requested => HouseholdRequestProgress.requested,
      PartnerRequestStatus.confirmed => HouseholdRequestProgress.confirmed,
      PartnerRequestStatus.completed => HouseholdRequestProgress.completed,
    };
  }

  @override
  Future<List<PartnerRequestData>> fetchAll() async =>
      _store.requests.toList(growable: false);

  @override
  Future<PartnerRequestData?> fetchRequest(String requestId) async =>
      _store.request(requestId);

  @override
  Future<PartnerRequestData> confirm(String requestId, String itemId) async =>
      _setOne(requestId, itemId, PartnerRequestStatus.confirmed);

  @override
  Future<PartnerRequestData> complete(String requestId, String itemId) async =>
      _setOne(requestId, itemId, PartnerRequestStatus.completed);

  /// 카드(항목)별로 독립된 확인·완료 상태를 관리한다 — 같은 요청의 다른 항목은
  /// 건드리지 않는다. 요청 전체 status는 PartnerRequestData.status getter가
  /// 항목 상태로부터 그때그때 계산한다.
  PartnerRequestData _setOne(
    String requestId,
    String itemId,
    PartnerRequestStatus status,
  ) {
    final current = _store.request(requestId);
    final updated = current.copyWith(
      tasks: [
        for (final task in current.tasks)
          if (task.id == itemId) task.copyWith(status: status) else task,
      ],
    );
    _store.save(updated);
    return updated;
  }
}
