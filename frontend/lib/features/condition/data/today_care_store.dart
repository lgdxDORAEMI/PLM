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

  @visibleForTesting
  void clear() {
    _today = null;
    notifyListeners();
  }
}
