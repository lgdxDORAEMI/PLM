import 'package:flutter/foundation.dart';

import '../models/invitation.dart';
import '../services/invitation_service.dart';

class InvitationEntryController extends ChangeNotifier {
  InvitationEntryController({required this.service, required this.token});

  final InvitationService service;
  final String? token;
  InvitationActionState _state = InvitationActionState.loading;
  InvitationTokenStatus _tokenStatus = InvitationTokenStatus.missing;

  InvitationActionState get state => _state;
  InvitationTokenStatus get tokenStatus => _tokenStatus;

  Future<void> validate() async {
    _state = InvitationActionState.loading;
    notifyListeners();
    try {
      _tokenStatus = await service.validateToken(token);
      _state = InvitationActionState.ready;
    } on Object {
      _state = InvitationActionState.error;
    }
    notifyListeners();
  }

  Future<bool> accept() async {
    final value = token;
    if (value == null || _tokenStatus != InvitationTokenStatus.valid) {
      return false;
    }
    _state = InvitationActionState.submitting;
    notifyListeners();
    try {
      await service.accept(value);
      _state = InvitationActionState.success;
      notifyListeners();
      return true;
    } on Object {
      _state = InvitationActionState.error;
      notifyListeners();
      return false;
    }
  }
}
