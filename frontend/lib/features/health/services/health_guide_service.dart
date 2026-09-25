import '../models/body_care_guide.dart';

enum HealthExecutionStatus { scheduled, completed, skipped }

abstract interface class HealthGuideService {
  Future<BodyCareGuideData> fetchGuide();

  Future<void> setStatus(String itemId, HealthExecutionStatus status);
}
