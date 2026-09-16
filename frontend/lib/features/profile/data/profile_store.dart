import 'package:flutter/foundation.dart';

import '../models/profile_draft.dart';

/// 인증·Profile API 전까지 화면 간 저장 결과를 공유하는 메모리 Mock이다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  ProfileDraft? _profile;
  ProfileDraft? get profile => _profile;
  bool get hasProfile => _profile != null;

  void save(ProfileDraft profile) {
    _profile = profile;
    notifyListeners();
  }

  void reset() {
    _profile = null;
    notifyListeners();
  }
}
