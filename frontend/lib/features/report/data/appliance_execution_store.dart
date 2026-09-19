import '../models/daily_record.dart';

enum ApplianceExecutionSource { household, sleep }

class ApplianceExecution {
  const ApplianceExecution({
    required this.date,
    required this.source,
    required this.label,
  });

  final DateTime date;
  final ApplianceExecutionSource source;
  final String label;
}

/// 가사·수면 가전 실행 요청을 날짜별로 모아 리포트에서 함께 조회한다.
class ApplianceExecutionStore {
  ApplianceExecutionStore._();

  static final instance = ApplianceExecutionStore._();

  final List<ApplianceExecution> _executions = [];

  void record({
    required ApplianceExecutionSource source,
    required String label,
    DateTime? date,
  }) {
    _executions.add(
      ApplianceExecution(
        date: date ?? DateTime.now(),
        source: source,
        label: label,
      ),
    );
  }

  List<ApplianceExecution> forDate(DateTime date) => List.unmodifiable(
    _executions.where(
      (entry) => recordDateKey(entry.date) == recordDateKey(date),
    ),
  );

  void reset() => _executions.clear();
}
