import 'package:flutter/foundation.dart';

import '../models/invitation.dart';
import '../services/invitation_service.dart';

class PartnerInviteController extends ChangeNotifier {
  PartnerInviteController({required this.service});

  final InvitationService service;
  InvitationActionState _state = InvitationActionState.loading;
  String? _link;

  InvitationActionState get state => _state;
  String? get link => _link;

  Future<void> load() async {
    _state = InvitationActionState.loading;
    notifyListeners();
    try {
      _link = await service.createLink();
      _state = InvitationActionState.ready;
    } on Object {
      _state = InvitationActionState.error;
    }
    notifyListeners();
  }

  /// 실제 OS 공유 Adapter가 연결되기 전까지 전송 대기 상태만 모사한다.
  Future<bool> send() async {
    if (_link == null || _state == InvitationActionState.submitting) {
      return false;
    }
    _state = InvitationActionState.submitting;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _state = InvitationActionState.success;
    notifyListeners();
    return true;
  }
}
