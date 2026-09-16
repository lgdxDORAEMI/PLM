import '../models/daily_routine.dart';
import 'routine_service.dart';

class MockRoutineService implements RoutineService {
  const MockRoutineService();

  static final todayPlan = DailyRoutinePlan(
    date: DateTime(2026, 9, 16),
    updatedLabel: '3분 전 루틴 업데이트',
    items: const [
      RoutineItem(
        id: 'meal-guide',
        title: '식사 가이드',
        description: '오늘은 입덧이 있어 속 편한 메뉴로',
        type: RoutineType.meal,
        status: RoutineStatus.scheduled,
      ),
      RoutineItem(
        id: 'household-guide',
        title: '가사 가이드',
        description: '허리 부담 큰 집안일은 가족에게 맡기고',
        type: RoutineType.household,
        status: RoutineStatus.scheduled,
      ),
      RoutineItem(
        id: 'health-guide',
        title: '건강 가이드',
        description: '허리·골반에 맞춘 오늘의 스트레칭',
        type: RoutineType.health,
        status: RoutineStatus.scheduled,
      ),
      RoutineItem(
        id: 'sleep-guide',
        title: '수면 가이드',
        description: '오늘 컨디션에 맞춰 잠자리 온도·조명 준비',
        type: RoutineType.sleep,
        status: RoutineStatus.scheduled,
      ),
    ],
  );

  static final fallbackPlan = DailyRoutinePlan(
    date: DateTime(2026, 9, 16),
    updatedLabel: '기본 루틴으로 준비했어요',
    items: todayPlan.items,
  );

  @override
  Future<DailyRoutinePlan> fetchToday() async => todayPlan;
}
