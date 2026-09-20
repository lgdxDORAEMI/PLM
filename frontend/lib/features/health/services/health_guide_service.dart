import '../models/body_care_guide.dart';

abstract interface class HealthGuideService {
  Future<BodyCareGuideData> fetchGuide();

  Future<void> setCompleted(String itemId, bool completed);
}
