import '../../../core/network/api_client.dart';
import '../models/daily_routine.dart';
import 'routine_service.dart';

/// Reads the current routine items used by the four detail screens.
class ApiRoutineService implements RoutineService {
  ApiRoutineService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static Map<String, dynamic>? _generatedToday;

  /// Keeps the POST response for the first home load, avoiding a duplicate GET.
  static void rememberGeneration(Map<String, dynamic> response) {
    _generatedToday = response;
  }

  @override
  Future<DailyRoutinePlan> fetchToday() async {
    final cached = _generatedToday;
    _generatedToday = null;
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
    final items = <RoutineItem>[];
    for (final type in RoutineType.values) {
      final guide = await _client.get(
        '/api/v1/${_guidePath(type)}/today',
        query: {'date': dateKey},
        throwOnNotFound: true,
      );
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
          ),
        );
      }
    }
    return DailyRoutinePlan(
      date: date,
      updatedLabel: json['source'] == 'ai' ? '오늘의 맞춤 루틴' : '오늘의 기본 루틴',
      items: items,
      isBackendFallback: json['source'] != 'ai',
    );
  }

  String _guidePath(RoutineType type) => switch (type) {
    RoutineType.meal => 'meals',
    RoutineType.household => 'household',
    RoutineType.health => 'health',
    RoutineType.sleep => 'sleep',
  };
}
