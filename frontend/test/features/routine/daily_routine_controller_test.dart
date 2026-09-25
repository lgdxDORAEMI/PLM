import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/routine/controllers/daily_routine_controller.dart';
import 'package:plm_frontend/features/routine/models/daily_routine.dart';
import 'package:plm_frontend/features/routine/services/mock_routine_service.dart';
import 'package:plm_frontend/features/routine/services/routine_service.dart';

void main() {
  test('Mock Service의 오늘 Routine을 로드한다', () async {
    final controller = DailyRoutineController(
      service: const MockRoutineService(),
      fallbackPlan: MockRoutineService.fallbackPlan,
    );
    addTearDown(controller.dispose);

    await controller.loadToday();

    expect(controller.state, RoutineViewState.ready);
    expect(controller.plan?.items, hasLength(4));
    expect(controller.plan?.items.first.type, RoutineType.meal);
  });

  test('Routine 조회 실패 시 기본 Routine으로 폴백한다', () async {
    final controller = DailyRoutineController(
      service: const _FailingRoutineService(),
      fallbackPlan: MockRoutineService.fallbackPlan,
    );
    addTearDown(controller.dispose);

    await controller.loadToday();

    expect(controller.state, RoutineViewState.fallback);
    expect(controller.isFallback, isTrue);
    expect(controller.plan, same(MockRoutineService.fallbackPlan));
  });

  test('기존 루틴이 있으면 갱신 중에도 결과와 ready 상태를 유지한다', () async {
    final service = _PendingRoutineService();
    final controller = DailyRoutineController(
      service: service,
      initialPlan: MockRoutineService.todayPlan,
    );
    addTearDown(controller.dispose);

    final refresh = controller.loadToday(forceRefresh: true);

    expect(controller.state, RoutineViewState.ready);
    expect(controller.plan, same(MockRoutineService.todayPlan));
    service.complete(MockRoutineService.todayPlan);
    await refresh;
    expect(controller.state, RoutineViewState.ready);
  });
}

class _FailingRoutineService implements RoutineService {
  const _FailingRoutineService();

  @override
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false}) {
    return Future.error(StateError('mock routine failure'));
  }
}

class _PendingRoutineService implements RoutineService {
  final _completer = Completer<DailyRoutinePlan>();

  void complete(DailyRoutinePlan plan) => _completer.complete(plan);

  @override
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false}) =>
      _completer.future;
}
