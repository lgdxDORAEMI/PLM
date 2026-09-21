import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../household/services/household_request_service.dart';
import '../data/partner_request_store.dart';
import '../models/partner_request.dart';

enum PartnerRequestViewState {
  loading,
  data,
  empty,
  authError,
  domainError,
  serverError,
  error,
}

class PartnerRequestController extends ChangeNotifier {
  PartnerRequestController({
    required this.requestId,
    required this.service,
    PartnerRequestStore? store,
  }) : store = store ?? PartnerRequestStore.instance;

  final String requestId;
  final HouseholdRequestService service;
  final PartnerRequestStore store;

  PartnerRequestViewState _state = PartnerRequestViewState.loading;
  PartnerRequestData? _request;

  PartnerRequestViewState get state => _state;
  PartnerRequestData? get request => _request;

  Future<void> load() async => _run(() => service.fetchRequest(requestId));

  Future<void> confirmTask(String taskId) async =>
      _run(() => service.confirm(requestId, taskId));

  Future<void> completeTask(String taskId) async =>
      _run(() => service.complete(requestId, taskId));

  /// 서버의 요청 전체 상태 전이를 그대로 반영하고 로컬 Store는 화면 간 캐시로만 쓴다.
  Future<void> _run(Future<PartnerRequestData?> Function() action) async {
    _state = PartnerRequestViewState.loading;
    notifyListeners();
    try {
      _request = await action();
      if (_request == null) {
        _state = PartnerRequestViewState.empty;
      } else {
        store.save(_request!);
        _state = PartnerRequestViewState.data;
      }
    } on ApiException catch (error) {
      _request = null;
      _state = switch (error.statusCode) {
        401 || 403 => PartnerRequestViewState.authError,
        409 || 422 => PartnerRequestViewState.domainError,
        503 => PartnerRequestViewState.serverError,
        _ => PartnerRequestViewState.error,
      };
    } on Object {
      _request = null;
      _state = PartnerRequestViewState.error;
    }
    notifyListeners();
  }
}
