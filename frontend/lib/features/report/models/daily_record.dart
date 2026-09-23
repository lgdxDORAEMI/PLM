enum ConditionLevel { good, normal, bad, difficult }

enum RecordCategory { meal, household, health, sleep }

enum RoutineRecordStatus { completed, skipped }

class RoutineRecord {
  const RoutineRecord({
    required this.title,
    required this.category,
    required this.status,
    this.completedByPartner = false,
  });

  final String title;
  final RecordCategory category;
  final RoutineRecordStatus status;
  final bool completedByPartner;
}

class DailyRecord {
  const DailyRecord({
    required this.date,
    required this.pregnancyWeek,
    required this.conditionLevel,
    required this.conditionSummary,
    required this.completedRoutines,
    required this.totalRoutines,
    required this.applianceSummary,
    required this.applianceCount,
    required this.routines,
    required this.familyRequested,
    required this.familyConfirmed,
    required this.familyCompleted,
    this.burdenArea = '허리',
    this.burdenCount = 0,
    this.motionSummaries = const [],
  });

  final DateTime date;
  final int pregnancyWeek;
  final ConditionLevel conditionLevel;
  final String conditionSummary;
  final int completedRoutines;
  final int totalRoutines;
  final String applianceSummary;
  final int applianceCount;
  final List<RoutineRecord> routines;
  final int familyRequested;
  final int familyConfirmed;
  final int familyCompleted;
  final String burdenArea;
  final int burdenCount;
  final List<String> motionSummaries;

  DailyRecord copyWithFamilySummary({
    required int requested,
    required int confirmed,
    required int completed,
  }) => DailyRecord(
    date: date,
    pregnancyWeek: pregnancyWeek,
    conditionLevel: conditionLevel,
    conditionSummary: conditionSummary,
    completedRoutines: completedRoutines,
    totalRoutines: totalRoutines,
    applianceSummary: applianceSummary,
    applianceCount: applianceCount,
    routines: routines,
    familyRequested: requested,
    familyConfirmed: confirmed,
    familyCompleted: completed,
    burdenArea: burdenArea,
    burdenCount: burdenCount,
    motionSummaries: motionSummaries,
  );

  DailyRecord copyWithApplianceSummary({
    required String summary,
    required int count,
  }) => DailyRecord(
    date: date,
    pregnancyWeek: pregnancyWeek,
    conditionLevel: conditionLevel,
    conditionSummary: conditionSummary,
    completedRoutines: completedRoutines,
    totalRoutines: totalRoutines,
    applianceSummary: summary,
    applianceCount: count,
    routines: routines,
    familyRequested: familyRequested,
    familyConfirmed: familyConfirmed,
    familyCompleted: familyCompleted,
    burdenArea: burdenArea,
    burdenCount: burdenCount,
    motionSummaries: motionSummaries,
  );
}

String recordDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
