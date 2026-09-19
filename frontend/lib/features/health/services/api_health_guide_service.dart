import '../../../core/network/api_client.dart';
import '../models/body_care_guide.dart';
import 'health_guide_service.dart';

class ApiHealthGuideService implements HealthGuideService {
  ApiHealthGuideService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<BodyCareGuideData> fetchGuide() async {
    final response = await _client.get('/api/v1/health/today');
    return response == null
        ? const BodyCareGuideData(loads: [], activities: [])
        : BodyCareGuideData.fromJson(response);
  }
}
