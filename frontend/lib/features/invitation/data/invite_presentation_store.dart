import 'package:flutter/foundation.dart';

import '../../../routing/app_session.dart';
import 'invite_presentation_persistence.dart';

/// Records when the wife has opened the linked-partner result in this app.
class InvitePresentationStore extends ChangeNotifier {
  InvitePresentationStore._();

  static final instance = InvitePresentationStore._();

  final Set<String> _acknowledgedInSession = {};

  bool get isAcknowledged {
    final accountId = AuthSessionStore.instance.accountId;
    return accountId != null &&
        (_acknowledgedInSession.contains(accountId) ||
            readInviteAcknowledged(accountId));
  }

  void acknowledgeLinkedPartner() {
    final accountId = AuthSessionStore.instance.accountId;
    if (accountId == null || isAcknowledged) return;
    _acknowledgedInSession.add(accountId);
    writeInviteAcknowledged(accountId);
    notifyListeners();
  }

  /// Reopens the invite step after a successful reset of today's experience.
  void resetForCurrentAccount() {
    final accountId = AuthSessionStore.instance.accountId;
    if (accountId == null) return;
    _acknowledgedInSession.remove(accountId);
    clearInviteAcknowledged(accountId);
    notifyListeners();
  }
}
