import 'package:flutter/foundation.dart';

import '../models/condition_draft.dart';

/// Backend 연결 전 Home과 Today Care가 공유하는 메모리 기반 당일 Store다.
class TodayCareStore extends ChangeNotifier {
  TodayCareStore._();

  static final TodayCareStore instance = TodayCareStore._();

  ConditionDraft? _today;

  ConditionDraft? get today => _today;
  bool get hasTodayCare => _today != null;

  void save(ConditionDraft value) {
    _today = value;
    notifyListeners();
  }

  /// 오늘 리포트를 저장하고 마칠 때 Home을 미입력 상태로 되돌린다.
  void finishDay() {
    _today = null;
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    finishDay();
  }
}
