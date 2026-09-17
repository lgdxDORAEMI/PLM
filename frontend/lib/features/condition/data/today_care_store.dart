import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/condition_draft.dart';
import 'condition_repository.dart';
import 'mock_condition_repository.dart';

/// Home과 Today Care가 공유하는 당일 컨디션 Store다.
///
/// STEP 15: 화면·Controller는 이 Store만 알고, Store는 [ConditionRepository]
/// 인터페이스만 안다 — Mock과 API 구현을 갈아 끼워도 위 두 계층은 바뀌지
/// 않는다. 기본값은 여전히 Mock이다(Frontend UI 개발 중 Mock Service를 쓰는
/// 기존 방침 유지, backend/README.md 참고) — API 구현으로 바꾸는 건 화면에
/// 로딩·오류 상태를 추가하는 별도 작업이라 이번 STEP에서는 기본값을 바꾸지
/// 않는다.
class TodayCareStore extends ChangeNotifier {
  TodayCareStore._({ConditionRepository? repository})
    : _repository = repository ?? MockConditionRepository();

  static final TodayCareStore instance = TodayCareStore._();

  /// Mock/API [ConditionRepository] 구현이 서로 바꿔 끼워져도 Store 동작이
  /// 같은지 테스트에서 확인할 때만 쓴다(STEP 15).
  @visibleForTesting
  factory TodayCareStore.withRepository(ConditionRepository repository) =>
      TodayCareStore._(repository: repository);

  final ConditionRepository _repository;
  ConditionDraft? _today;

  ConditionDraft? get today => _today;
  bool get hasTodayCare => _today != null;

  void save(ConditionDraft value) {
    _today = value;
    notifyListeners();
    // ponytail: fire-and-forget — 기존 UI가 동기 save()를 그대로 호출하므로
    // 로딩 상태 없이 낙관적으로 반영한다. Mock은 항상 즉시 성공한다. API
    // 구현으로 바꿀 때는 화면에 로딩/오류 처리를 추가하면서 await 가능한
    // save()로 승격한다.
    unawaited(_repository.saveToday(DateTime.now(), value));
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
