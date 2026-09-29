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
    this.awaitingCondition = false,
  });

  /// 09-29: 그날 컨디션이 아직 없는 날. 남편 화면이 날짜·주차만 보여줄 때 쓴다.
  const DailyRecord.awaitingCondition({
    required this.date,
    required this.pregnancyWeek,
  }) : conditionLevel = ConditionLevel.normal,
       conditionSummary = '',
       completedRoutines = 0,
       totalRoutines = 0,
       applianceSummary = '',
       applianceCount = 0,
       routines = const [],
       familyRequested = 0,
       familyConfirmed = 0,
       familyCompleted = 0,
       burdenArea = '',
       burdenCount = 0,
       motionSummaries = const [],
       awaitingCondition = true;

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
  final bool awaitingCondition;

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
    awaitingCondition: awaitingCondition,
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
    awaitingCondition: awaitingCondition,
  );
}

String recordDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
