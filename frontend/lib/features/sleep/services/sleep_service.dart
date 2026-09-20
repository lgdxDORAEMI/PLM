import '../models/sleep_guide.dart';

abstract interface class SleepService {
  Future<SleepGuideData> fetchGuide();

  Future<void> updateEnvironment(String itemId, Map<String, dynamic> values);
}
