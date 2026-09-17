import 'package:flutter/foundation.dart';

import '../models/profile_draft.dart';
import 'profile_persistence.dart';

/// 인증·Profile API 전까지 메모리와 브라우저 저장소로 Demo 상태를 공유한다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  ProfileDraft? _profile = readStoredProfile();
  ProfileDraft? get profile => _profile;
  bool get hasProfile => _profile?.isComplete ?? false;

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
