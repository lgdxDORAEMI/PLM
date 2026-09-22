import 'planned_activity_service.dart';

class MockPlannedActivityService implements PlannedActivityService {
  const MockPlannedActivityService();

  @override
  Future<List<String>> fetch(DateTime date) async => const [];

  @override
  Future<void> saveAndGenerate(DateTime date, List<String> activities) =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  @override
  Future<void> saveActivities(DateTime date, List<String> activities) async {}

  @override
  Future<void> generateRoutine() =>
      Future<void>.delayed(const Duration(milliseconds: 300));
}
