import '../../../core/network/api_client.dart';
import '../models/body_care_guide.dart';
import 'health_guide_service.dart';

class ApiHealthGuideService implements HealthGuideService {
  ApiHealthGuideService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<void> setCompleted(String itemId, bool completed) async {
    await _client.put(
      '/api/v1/care/routine-items/${Uri.encodeComponent(itemId)}/execution',
      {'status': completed ? 'completed' : 'scheduled'},
    );
  }

  @override
  Future<BodyCareGuideData> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/health/today',
      throwOnNotFound: true,
    );
    return response == null
        ? const BodyCareGuideData(loads: [], activities: [])
        : BodyCareGuideData.fromJson(response);
  }
}
