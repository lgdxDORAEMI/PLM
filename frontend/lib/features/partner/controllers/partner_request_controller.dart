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

  /// 남편 DB 문서에 따라 요청 카드 전체를 하나의 상태로 전환한다.
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

  void _save(PartnerRequestData value) {
    _request = value;
    store.save(value);
    notifyListeners();
  }
}
