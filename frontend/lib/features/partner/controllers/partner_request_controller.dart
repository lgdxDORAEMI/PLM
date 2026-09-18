import 'package:flutter/foundation.dart';

import '../data/partner_request_store.dart';
import '../models/partner_request.dart';

class PartnerRequestController extends ChangeNotifier {
  PartnerRequestController({
    required this.requestId,
    PartnerRequestStore? store,
  }) : store = store ?? PartnerRequestStore.instance,
       _request = (store ?? PartnerRequestStore.instance).request(requestId);

  final String requestId;
  final PartnerRequestStore store;
  PartnerRequestData _request;

  PartnerRequestData get request => _request;

  /// 선택한 집안일만 확인 처리해 다른 카드의 진행 상태를 보존한다.
  void confirmTask(String taskId) => _updateTaskStatus(
    taskId,
    from: PartnerRequestStatus.requested,
    to: PartnerRequestStatus.confirmed,
  );

  /// 확인된 집안일만 완료할 수 있도록 상태 순서를 강제한다.
  void completeTask(String taskId) => _updateTaskStatus(
    taskId,
    from: PartnerRequestStatus.confirmed,
    to: PartnerRequestStatus.completed,
  );

  void _updateTaskStatus(
    String taskId, {
    required PartnerRequestStatus from,
    required PartnerRequestStatus to,
  }) {
    final tasks = [
      for (final task in _request.tasks)
        if (task.id == taskId && task.status == from)
          task.copyWith(status: to)
        else
          task,
    ];
    _save(_request.copyWith(tasks: tasks));
  }

  void _save(PartnerRequestData value) {
    _request = value;
    store.save(value);
    notifyListeners();
  }
}
