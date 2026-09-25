import 'package:flutter/foundation.dart';

import '../models/daily_routine.dart';
import '../services/routine_service.dart';

enum RoutineViewState { idle, loading, ready, fallback, error }

/// Routine 조회·폴백 상태를 Home Widget과 분리한다.
class DailyRoutineController extends ChangeNotifier {
  DailyRoutineController({
    required this.service,
    this.fallbackPlan,
    DailyRoutinePlan? initialPlan,
  }) : _state = initialPlan == null
           ? RoutineViewState.idle
           : initialPlan.isBackendFallback
           ? RoutineViewState.fallback
           : RoutineViewState.ready,
       _plan = initialPlan;

  final RoutineService service;
  final DailyRoutinePlan? fallbackPlan;

  RoutineViewState _state;
  DailyRoutinePlan? _plan;

  RoutineViewState get state => _state;
  DailyRoutinePlan? get plan => _plan;
  bool get isFallback => _state == RoutineViewState.fallback;

  /// 중복 요청을 막고 실패 시 빈 화면 대신 기본 Routine을 제공한다.
  Future<void> loadToday({bool forceRefresh = false}) async {
    if (_state == RoutineViewState.loading) return;
    final previousPlan = _plan;
    final previousState = _state;
    if (previousPlan == null) _state = RoutineViewState.loading;
    notifyListeners();
    try {
      _plan = await service.fetchToday(forceRefresh: forceRefresh);
      _state = _plan!.isBackendFallback
          ? RoutineViewState.fallback
          : RoutineViewState.ready;
    } on Object {
      if (previousPlan != null) {
        _plan = previousPlan;
        _state = previousState;
      } else {
        _plan = fallbackPlan;
        _state = fallbackPlan == null
            ? RoutineViewState.error
            : RoutineViewState.fallback;
      }
    }
    notifyListeners();
  }
}
