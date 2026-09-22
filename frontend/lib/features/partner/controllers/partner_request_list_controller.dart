import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../household/services/household_request_service.dart';
import '../models/partner_request.dart';
import 'partner_request_controller.dart';

class PartnerRequestListController extends ChangeNotifier {
  PartnerRequestListController({required this.service});

  final HouseholdRequestService service;
  PartnerRequestViewState _state = PartnerRequestViewState.loading;
  List<PartnerRequestData> _requests = const [];

  PartnerRequestViewState get state => _state;
  List<PartnerRequestData> get requests => List.unmodifiable(_requests);

  /// Load every request independently of the notification that opened the page.
  Future<void> load() async {
    _state = PartnerRequestViewState.loading;
    notifyListeners();
    try {
      final records = (await service.fetchAll()).indexed.toList();
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
}
