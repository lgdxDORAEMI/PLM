import '../../../core/network/api_client.dart';
import 'planned_activity_service.dart';

class ApiPlannedActivityService implements PlannedActivityService {
  ApiPlannedActivityService({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<String>> fetch(DateTime date) async {
    final response = await _client.get('/api/v1/care/conditions/${_key(date)}');
    return (response?['planned_activities'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const [];
  }

  @override
  Future<void> saveAndGenerate(DateTime date, List<String> activities) async {
    await _client.put('/api/v1/care/conditions/${_key(date)}/activities', {
      'activities': activities,
    });
    await _client.post('/api/v1/routine/today');
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
