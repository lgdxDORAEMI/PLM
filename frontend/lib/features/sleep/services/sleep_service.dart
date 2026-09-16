import '../models/sleep_guide.dart';

abstract interface class SleepService {
  Future<SleepGuideData> fetchGuide();
}
