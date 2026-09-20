/// Routine API 응답으로 교체할 수 있는 화면용 카테고리다.
enum RoutineType { meal, household, health, sleep }

/// 화면이 지원할 Routine 진행 상태다. 현재 Home 시안은 예정 상태만 노출한다.
enum RoutineStatus { scheduled, completed, skipped }

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.time,
  });

  final String id;
  final String title;
  final String description;
  final RoutineType type;
  final RoutineStatus status;
  final String? time;
}

class DailyRoutinePlan {
  const DailyRoutinePlan({
    required this.date,
    required this.updatedLabel,
    required this.items,
    this.isBackendFallback = false,
  });

  final DateTime date;
  final String updatedLabel;
  final List<RoutineItem> items;
  final bool isBackendFallback;
}
