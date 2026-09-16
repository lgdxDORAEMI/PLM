import 'package:flutter/foundation.dart';

import '../models/daily_routine.dart';
import '../services/routine_service.dart';

enum RoutineViewState { idle, loading, ready, fallback }

/// Routine 조회·폴백 상태를 Home Widget과 분리한다.
class DailyRoutineController extends ChangeNotifier {
  DailyRoutineController({required this.service, required this.fallbackPlan});

  final RoutineService service;
  final DailyRoutinePlan fallbackPlan;

  RoutineViewState _state = RoutineViewState.idle;
  DailyRoutinePlan? _plan;

  RoutineViewState get state => _state;
  DailyRoutinePlan? get plan => _plan;
  bool get isFallback => _state == RoutineViewState.fallback;

  /// 중복 요청을 막고 실패 시 빈 화면 대신 기본 Routine을 제공한다.
  Future<void> loadToday() async {
    if (_state == RoutineViewState.loading) return;
    _state = RoutineViewState.loading;
    notifyListeners();
    try {
      _plan = await service.fetchToday();
      _state = RoutineViewState.ready;
    } on Object {
      _plan = fallbackPlan;
      _state = RoutineViewState.fallback;
    }
    notifyListeners();
  }
}
