import '../../../core/network/api_client.dart';
import '../models/daily_routine.dart';
import 'routine_service.dart';

/// Reads the saved daily routine from the backend's four guide categories.
class ApiRoutineService implements RoutineService {
  ApiRoutineService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<DailyRoutinePlan> fetchToday() async {
    final json = await _client.get('/api/v1/routine/today');
    if (json == null) throw StateError('오늘 생성된 루틴이 없습니다.');
    final response = json['response'];
    if (response is! Map) throw const FormatException('루틴 응답 형식이 올바르지 않습니다.');
    final items = <RoutineItem>[];
    for (final type in RoutineType.values) {
      final raw = response[type.name];
      final entries = raw is List
          ? raw
          : raw is Map
          ? [raw]
          : const [];
      for (final entry in entries) {
        if (entry is! Map) continue;
        final payload = entry['payload'];
        final details = payload is Map ? payload : const {};
        items.add(
          RoutineItem(
            id: entry['item_key']?.toString() ?? '${type.name}:${items.length}',
            title: entry['title']?.toString() ?? '',
            description: details['reason']?.toString() ?? '',
            type: type,
            status: RoutineStatus.scheduled,
            time: details['time']?.toString(),
          ),
        );
      }
    }
    return DailyRoutinePlan(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      updatedLabel: json['source'] == 'ai' ? '오늘의 맞춤 루틴' : '오늘의 기본 루틴',
      items: items,
    );
  }
}
