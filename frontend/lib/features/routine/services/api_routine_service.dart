import '../../../core/network/api_client.dart';
import '../models/daily_routine.dart';
import 'routine_service.dart';

/// Reads the current routine items used by the four detail screens.
class ApiRoutineService implements RoutineService {
  ApiRoutineService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static Map<String, dynamic>? _generatedToday;
  static DailyRoutinePlan? _cachedToday;

  /// 홈 화면이 다시 만들어져도 오늘 루틴을 즉시 복원할 수 있는 화면 캐시다.
  static DailyRoutinePlan? get cachedToday {
    final cached = _cachedToday;
    if (cached == null || !_isToday(cached.date)) {
      _cachedToday = null;
      return null;
    }
    return cached;
  }

  /// Keeps the POST response for the first home load, avoiding a duplicate GET.
  static void rememberGeneration(Map<String, dynamic> response) {
    _generatedToday = response;
  }

  /// Removes a pending generation result before another account becomes active.
  static void clearGeneration() {
    _generatedToday = null;
    _cachedToday = null;
  }

  static void invalidateCache() => _cachedToday = null;

  @override
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false}) async {
    final cached = _generatedToday;
    _generatedToday = null;
    final parsedCache = cachedToday;
    if (cached == null && !forceRefresh && parsedCache != null) {
      return parsedCache;
    }
    final today = DateTime.now().toUtc().add(const Duration(hours: 9));
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final json = cached != null && cached['date'] == todayKey
        ? cached
        : await _client.get('/api/v1/routine/today', throwOnNotFound: true);
    if (json == null) throw StateError('오늘 생성된 루틴이 없습니다.');
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    if (date == null) throw const FormatException('루틴 날짜가 없습니다.');
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final home = json['home'];
    final summaries = home is Map ? home['summaries'] : null;
    if (summaries is! Map) {
      throw const FormatException('홈 가이드 요약이 없습니다.');
    }
    final homeCards = [
      for (final type in RoutineType.values)
        RoutineItem(
          id: 'home:${type.name}',
          title: _guideTitle(type),
          description: _summaryFor(summaries, type),
          type: type,
          status: RoutineStatus.scheduled,
        ),
    ];
    // 09-25: 4종 가이드는 서로 독립이라 함께 보낸다. 순차 await면 왕복 4번을 그대로 기다렸다.
    final guides = await Future.wait([
      for (final type in RoutineType.values)
        _client.get(
          '/api/v1/${_guidePath(type)}/today',
          query: {'date': dateKey},
          throwOnNotFound: true,
        ),
    ]);
    final items = <RoutineItem>[];
    for (final (index, type) in RoutineType.values.indexed) {
      final guide = guides[index];
      if (guide?['date'] != dateKey || guide?['category'] != type.name) {
        throw const FormatException('루틴 가이드 날짜 또는 종류가 일치하지 않습니다.');
      }
      final entries = guide?['items'];
      if (entries is! List) throw const FormatException('루틴 항목 형식이 올바르지 않습니다.');
      for (final entry in entries.whereType<Map>()) {
        final id = entry['item_id']?.toString();
        if (id == null || id.isEmpty) {
          throw const FormatException('루틴 항목 번호가 없습니다.');
        }
        final payload = entry['payload'];
        final details = payload is Map ? payload : const {};
        items.add(
          RoutineItem(
            id: id,
            title: entry['title']?.toString() ?? '',
            description:
                entry['description']?.toString() ??
                details['reason']?.toString() ??
                '',
            type: type,
            status: switch (entry['status']) {
              'completed' => RoutineStatus.completed,
              'skipped' => RoutineStatus.skipped,
              _ => RoutineStatus.scheduled,
            },
            time: details['time']?.toString(),
            bodyArea: details['bodyArea']?.toString(),
            countsTowardProgress:
                type != RoutineType.health || details['isFocus'] != false,
          ),
        );
      }
    }
    final plan = DailyRoutinePlan(
      date: date,
      updatedLabel: json['source'] == 'ai' ? '오늘의 맞춤 루틴' : '오늘의 기본 루틴',
      items: items,
      homeCards: homeCards,
      isBackendFallback: json['source'] != 'ai',
      weekNotes: home is Map
          ? ((home['week_notes'] as List?)?.whereType<String>().toList() ??
                const [])
          : const [],
      caution: home is Map ? home['caution'] as String? : null,
    );
    _cachedToday = plan;
    return plan;
  }

  static bool _isToday(DateTime date) {
    final today = DateTime.now().toUtc().add(const Duration(hours: 9));
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  String _summaryFor(Map summaries, RoutineType type) {
    final value = summaries[type.name];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('${type.name} 홈 가이드 요약이 없습니다.');
    }
    return value;
  }

  String _guideTitle(RoutineType type) => switch (type) {
    RoutineType.meal => '식사 가이드',
    RoutineType.household => '가사 가이드',
    RoutineType.health => '건강 가이드',
    RoutineType.sleep => '수면 가이드',
  };

  String _guidePath(RoutineType type) => switch (type) {
    RoutineType.meal => 'meals',
    RoutineType.household => 'household',
    RoutineType.health => 'health',
    RoutineType.sleep => 'sleep',
  };
}
