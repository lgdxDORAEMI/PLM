import 'package:flutter/foundation.dart';

import '../../../routing/app_session.dart';
import '../models/profile_draft.dart';
import 'profile_persistence.dart';
import 'profile_reentry_persistence.dart';

/// 인증·Profile API 전까지 메모리와 브라우저 저장소로 Demo 상태를 공유한다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  ProfileDraft? _profile = readStoredProfile();
  final Set<String> _reentryAccounts = {};
  ProfileDraft? get profile => _profile;
  bool get hasProfile => _profile?.isComplete ?? false;

  bool get requiresReentry {
    final accountId = AuthSessionStore.instance.accountId;
    return accountId != null && requiresReentryFor(accountId);
  }

  bool requiresReentryFor(String accountId) =>
      _reentryAccounts.contains(accountId) || readProfileReentry(accountId);

  /// Require a fresh six-step profile after today's successful reset.
  void requireReentry() {
    final accountId = AuthSessionStore.instance.accountId;
    if (accountId == null) return;
    _reentryAccounts.add(accountId);
    writeProfileReentry(accountId, true);
    notifyListeners();
  }

  /// Clear the gate only after the complete profile has been saved.
  void completeReentry() {
    final accountId = AuthSessionStore.instance.accountId;
    if (accountId == null) return;
    _reentryAccounts.remove(accountId);
    writeProfileReentry(accountId, false);
    notifyListeners();
  }

  void save(ProfileDraft profile) {
    _profile = profile;
    writeStoredProfile(profile);
    notifyListeners();
  }

  void reset() {
    _profile = null;
    writeStoredProfile(null);
    notifyListeners();
  }
}
