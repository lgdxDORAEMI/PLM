import '../models/body_care_guide.dart';
import 'health_guide_service.dart';

class MockHealthGuideService implements HealthGuideService {
  const MockHealthGuideService();

  @override
  Future<BodyCareGuideData> fetchGuide() async => const BodyCareGuideData(
    loads: BodyCareMockData.loads,
    activities: BodyCareMockData.activities,
  );
}
