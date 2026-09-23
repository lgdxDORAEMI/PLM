import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../household/services/household_request_service.dart';
import '../models/partner_request.dart';
import 'partner_request_controller.dart';

class PartnerRequestListController extends ChangeNotifier {
  PartnerRequestListController({required this.service, this.targetDate});

  final HouseholdRequestService service;
  final String? targetDate;
  PartnerRequestViewState _state = PartnerRequestViewState.loading;
  List<PartnerRequestData> _requests = const [];
  final Set<String> _updatingItems = <String>{};

  PartnerRequestViewState get state => _state;
  List<PartnerRequestData> get requests => List.unmodifiable(_requests);
  bool isUpdating(String itemId) => _updatingItems.contains(itemId);

  /// 요청 항목은 미확인, 확인, 완료 순으로 두고 같은 상태에서는 최신 요청을 먼저 둔다.
  List<PartnerRequestListItem> get items {
    final result = <PartnerRequestListItem>[
      for (final request in _requests)
        for (final task in request.tasks)
          PartnerRequestListItem(request: request, task: task),
    ];
    result.sort((a, b) {
      final byStatus = _statusOrder(
        a.task.status,
      ).compareTo(_statusOrder(b.task.status));
      if (byStatus != 0) return byStatus;
      final byTime = (b.request.requestedAt ?? DateTime(0)).compareTo(
        a.request.requestedAt ?? DateTime(0),
      );
      return byTime != 0 ? byTime : b.task.id.compareTo(a.task.id);
    });
    return List.unmodifiable(result);
  }

  /// 알림에서 전달된 날짜가 있으면 그 날짜의 요청만 화면 데이터로 유지한다.
  Future<void> load() async {
    _state = PartnerRequestViewState.loading;
    notifyListeners();
    try {
      final records = (await service.fetchAll())
          .where(
            (request) => targetDate == null || request.recordDate == targetDate,
          )
          .indexed
          .toList();
      records.sort((a, b) {
        final byDate = b.$2.recordDate.compareTo(a.$2.recordDate);
        if (byDate != 0) return byDate;
        final byTime = (b.$2.requestedAt ?? DateTime(0)).compareTo(
          a.$2.requestedAt ?? DateTime(0),
        );
        return byTime != 0 ? byTime : b.$1.compareTo(a.$1);
      });
      _requests = records.map((entry) => entry.$2).toList(growable: false);
      _state = _requests.isEmpty
          ? PartnerRequestViewState.empty
          : PartnerRequestViewState.data;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => PartnerRequestViewState.authError,
        503 => PartnerRequestViewState.serverError,
        _ => PartnerRequestViewState.error,
      };
    } on Object {
      _state = PartnerRequestViewState.error;
    }
    notifyListeners();
  }

  Future<bool> confirmTask(String requestId, String itemId) =>
      _update(requestId, itemId, service.confirm);

  Future<bool> completeTask(String requestId, String itemId) =>
      _update(requestId, itemId, service.complete);

  /// 서버가 반환한 요청 전체를 교체해 항목 상태와 정렬을 즉시 함께 갱신한다.
  Future<bool> _update(
    String requestId,
    String itemId,
    Future<PartnerRequestData> Function(String, String) action,
  ) async {
    if (_updatingItems.contains(itemId)) return false;
    _updatingItems.add(itemId);
    notifyListeners();
    try {
      final updated = await action(requestId, itemId);
      _requests = [
        for (final request in _requests)
          if (request.id == requestId) updated else request,
      ];
      _state = PartnerRequestViewState.data;
      return true;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => PartnerRequestViewState.authError,
        409 || 422 => PartnerRequestViewState.domainError,
        503 => PartnerRequestViewState.serverError,
        _ => PartnerRequestViewState.error,
      };
      return false;
    } on Object {
      _state = PartnerRequestViewState.error;
      return false;
    } finally {
      _updatingItems.remove(itemId);
      notifyListeners();
    }
  }
}

class PartnerRequestListItem {
  const PartnerRequestListItem({required this.request, required this.task});

  final PartnerRequestData request;
  final PartnerRequestTask task;
}

int _statusOrder(PartnerRequestStatus status) => switch (status) {
  PartnerRequestStatus.requested => 0,
  PartnerRequestStatus.confirmed => 1,
  PartnerRequestStatus.completed => 2,
};
