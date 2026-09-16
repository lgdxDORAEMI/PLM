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
}

class _FailingRoutineService implements RoutineService {
  const _FailingRoutineService();

  @override
  Future<DailyRoutinePlan> fetchToday() {
    return Future.error(StateError('mock routine failure'));
  }
}
