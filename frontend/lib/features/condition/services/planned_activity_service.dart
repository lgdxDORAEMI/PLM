abstract interface class PlannedActivityService {
  Future<List<String>> fetch(DateTime date);

  Future<void> saveAndGenerate(DateTime date, List<String> activities);
}
