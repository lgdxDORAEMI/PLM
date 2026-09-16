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

  void confirm() {
    if (_request.status != PartnerRequestStatus.requested) return;
    _save(_request.copyWith(status: PartnerRequestStatus.confirmed));
  }

  void complete() {
    if (_request.status != PartnerRequestStatus.confirmed) return;
    _save(_request.copyWith(status: PartnerRequestStatus.completed));
  }

  void _save(PartnerRequestData value) {
    _request = value;
    store.save(value);
    notifyListeners();
  }
}
