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

  void confirmTask(String taskId) => _updateTask(
    taskId,
    from: PartnerRequestStatus.requested,
    to: PartnerRequestStatus.confirmed,
  );

  void completeTask(String taskId) => _updateTask(
    taskId,
    from: PartnerRequestStatus.confirmed,
    to: PartnerRequestStatus.completed,
  );

  /// 기존 Household 상태 계약에서는 전체 요청의 단계 전환으로 집계한다.
  void confirm() {
    _save(
      _request.copyWith(
        tasks: [
          for (final task in _request.tasks)
            if (task.status == PartnerRequestStatus.requested)
              task.copyWith(status: PartnerRequestStatus.confirmed)
            else
              task,
        ],
      ),
    );
  }

  void complete() {
    _save(
      _request.copyWith(
        tasks: [
          for (final task in _request.tasks)
            if (task.status == PartnerRequestStatus.confirmed)
              task.copyWith(status: PartnerRequestStatus.completed)
            else
              task,
        ],
      ),
    );
  }

  void _updateTask(
    String taskId, {
    required PartnerRequestStatus from,
    required PartnerRequestStatus to,
  }) {
    _save(
      _request.copyWith(
        tasks: [
          for (final task in _request.tasks)
            if (task.id == taskId && task.status == from)
              task.copyWith(status: to)
            else
              task,
        ],
      ),
    );
  }

  void _save(PartnerRequestData value) {
    _request = value;
    store.save(value);
    notifyListeners();
  }
}
