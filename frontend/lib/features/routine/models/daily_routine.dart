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
    this.bodyArea,
    this.countsTowardProgress = true,
  });

  final String id;
  final String title;
  final String description;
  final RoutineType type;
  final RoutineStatus status;
  final String? time;
  final String? bodyArea;
  final bool countsTowardProgress;

  RoutineItem copyWith({RoutineStatus? status}) => RoutineItem(
    id: id,
    title: title,
    description: description,
    type: type,
    status: status ?? this.status,
    time: time,
    bodyArea: bodyArea,
    countsTowardProgress: countsTowardProgress,
  );
}

class DailyRoutinePlan {
  const DailyRoutinePlan({
    required this.date,
    required this.updatedLabel,
    required this.items,
    this.homeCards = const [],
    this.isBackendFallback = false,
    this.weekNotes = const [],
    this.caution,
  });

  final DateTime date;
  final String updatedLabel;
  final List<RoutineItem> items;

  /// Backend home.summaries에서 만든 카테고리별 홈 카드 네 장.
  final List<RoutineItem> homeCards;
  final bool isBackendFallback;

  /// Backend home.week_notes: 주차별 고정 안내 2줄(09-22). 없으면 빈 목록.
  final List<String> weekNotes;

  /// Backend home.caution: 오늘의 팁(AI)이 있으면 그 문장, 없으면 주차별 주의 문구.
  final String? caution;

  DailyRoutinePlan copyWith({List<RoutineItem>? items}) => DailyRoutinePlan(
    date: date,
    updatedLabel: updatedLabel,
    items: items ?? this.items,
    homeCards: homeCards,
    isBackendFallback: isBackendFallback,
    weekNotes: weekNotes,
    caution: caution,
  );
}
