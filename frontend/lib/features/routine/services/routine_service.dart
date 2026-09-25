import '../models/daily_routine.dart';

/// 실제 AI/API가 연결되기 전에도 Home이 데이터 출처와 분리되도록 하는 경계다.
abstract interface class RoutineService {
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false});
}
