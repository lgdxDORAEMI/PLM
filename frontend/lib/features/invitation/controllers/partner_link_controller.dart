import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/partner_link.dart';
import '../services/partner_link_service.dart';

enum PartnerLinkViewState { loading, data, authError, serverError, error }

class PartnerLinkController extends ChangeNotifier {
  PartnerLinkController({required this.service});

  final PartnerLinkService service;
  PartnerLinkViewState _state = PartnerLinkViewState.loading;
  PartnerLink? _link;

  PartnerLinkViewState get state => _state;
  PartnerLink? get link => _link;

  Future<void> load() async {
    _state = PartnerLinkViewState.loading;
    notifyListeners();
    try {
      _link = await service.fetch();
      _state = PartnerLinkViewState.data;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => PartnerLinkViewState.authError,
        503 => PartnerLinkViewState.serverError,
        _ => PartnerLinkViewState.error,
      };
    } on Object {
      _state = PartnerLinkViewState.error;
    }
    notifyListeners();
  }
}
