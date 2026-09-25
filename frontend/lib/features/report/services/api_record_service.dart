import '../../../core/network/api_client.dart';
import '../../profile/data/profile_store.dart';
import '../models/daily_record.dart';
import 'record_service.dart';

/// Reads calendar and daily report projections from the existing care APIs.
class ApiRecordService implements RecordService {
  ApiRecordService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<DailyRecord>> fetchMonth(DateTime month) async {
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    final response = await _client.get('/api/v1/care/calendar/$monthKey');
    final days = response?['days'];
    if (days is! List) return const [];
    return days
        .whereType<Map>()
        .map((day) {
          final date =
              DateTime.tryParse(day['target_date']?.toString() ?? '') ?? month;
          return _emptyRecord(
            date,
            level: _level(day['condition_index']?.toString()),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<DailyRecord?> fetchCalendarRecord(DateTime date) async {
    final key = recordDateKey(date);
    final response = await _client.get('/api/v1/care/calendar/days/$key');
    // Backend보다 Frontend가 먼저 배포된 동안에는 기존 상세 조회 계약으로
    // 폴백해 캘린더 상세가 비는 배포 순서 문제를 막는다.
    if (response == null) return fetchRecord(date);
    final report = response['report'];
    final condition = response['condition'];
    if (report is! Map || condition is! Map) {
      throw const FormatException('캘린더 상세 응답 형식이 올바르지 않습니다.');
    }
    return _fromResponse(
      date,
      Map<String, dynamic>.from(report),
      Map<String, dynamic>.from(condition),
    );
  }

  @override
  Future<DailyRecord?> fetchRecord(DateTime date) async {
    final key = recordDateKey(date);
    var response = await _client.get('/api/v1/care/daily-reports/$key');
    response ??= await _client.post('/api/v1/care/daily-reports/$key/preview');
    if (response == null) return null;
    final condition = await _client.get('/api/v1/care/conditions/$key');
    return _fromResponse(date, response, condition);
  }

  @override
  Future<void> saveRecord(DailyRecord record) async {
    await _client.post(
      '/api/v1/care/daily-reports/${recordDateKey(record.date)}/finalize',
    );
  }

  @override
  Future<void> shareRecord(DailyRecord record) => saveRecord(record);

  DailyRecord _fromResponse(
    DateTime date,
    Map<String, dynamic> report,
    Map<String, dynamic>? condition,
  ) {
    final rawRoutines = report['routines'];
    final routines = rawRoutines is List
        ? rawRoutines
              .whereType<Map>()
              .where(
                (item) =>
                    item['status'] == 'completed' ||
                    item['status'] == 'skipped',
              )
              .map((item) {
                final category = RecordCategory.values.firstWhere(
                  (value) => value.name == item['category'],
                  orElse: () => RecordCategory.health,
                );
                return RoutineRecord(
                  title: item['title']?.toString() ?? '',
                  category: category,
                  status: item['status'] == 'completed'
                      ? RoutineRecordStatus.completed
                      : RoutineRecordStatus.skipped,
                  completedByPartner: item['completed_by'] == 'husband',
                );
              })
              .toList(growable: false)
        : <RoutineRecord>[];
    final family = report['family'];
    final counts = family is Map ? family : const {};
    final applianceCount =
        (report['appliance_executions'] as num?)?.toInt() ?? 0;
    return DailyRecord(
      date: date,
      pregnancyWeek: ProfileStore.instance.profile?.pregnancyWeekAt(date) ?? 0,
      conditionLevel: _conditionLevel(condition),
      conditionSummary: _conditionSummary(condition),
      completedRoutines: (report['completed_routines'] as num?)?.toInt() ?? 0,
      totalRoutines: rawRoutines is List ? rawRoutines.length : 0,
      applianceSummary: applianceCount == 0
          ? '실행 기록 없음'
          : '$applianceCount건 실행',
      applianceCount: applianceCount,
      routines: routines,
      familyRequested: (counts['requested'] as num?)?.toInt() ?? 0,
      familyConfirmed: (counts['confirmed'] as num?)?.toInt() ?? 0,
      familyCompleted: (counts['completed'] as num?)?.toInt() ?? 0,
      burdenArea: report['highest_load_area']?.toString() ?? '',
      burdenCount: report['motion_cautions'] is List
          ? (report['motion_cautions'] as List).length
          : 0,
      motionSummaries:
          (report['motion_summaries'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  DailyRecord _emptyRecord(DateTime date, {required ConditionLevel level}) =>
      DailyRecord(
        date: date,
        pregnancyWeek:
            ProfileStore.instance.profile?.pregnancyWeekAt(date) ?? 0,
        conditionLevel: level,
        conditionSummary: '컨디션 기록 있음',
        completedRoutines: 0,
        totalRoutines: 0,
        applianceSummary: '실행 기록 없음',
        applianceCount: 0,
        routines: const [],
        familyRequested: 0,
        familyConfirmed: 0,
        familyCompleted: 0,
      );

  ConditionLevel _conditionLevel(Map<String, dynamic>? json) {
    if (json == null) return ConditionLevel.normal;
    const keys = [
      'nausea',
      'waist_pain',
      'pelvis_pain',
      'leg_pain',
      'wrist_pain',
      'fatigue',
    ];
    final scores = keys.map((key) => json[key]).whereType<num>().toList();
    if (scores.isEmpty) return ConditionLevel.normal;
    final average = scores.reduce((a, b) => a + b) / scores.length;
    return average <= 2
        ? ConditionLevel.good
        : average <= 3
        ? ConditionLevel.normal
        : average <= 4
        ? ConditionLevel.bad
        : ConditionLevel.difficult;
  }

  ConditionLevel _level(String? value) => switch (value) {
    'good' => ConditionLevel.good,
    'bad' => ConditionLevel.bad,
    'hard' => ConditionLevel.difficult,
    _ => ConditionLevel.normal,
  };

  String _conditionSummary(Map<String, dynamic>? condition) {
    if (condition == null) return '컨디션 기록 없음';
    const labels = {
      'nausea': '입덧',
      'waist_pain': '허리',
      'pelvis_pain': '골반',
      'leg_pain': '다리',
      'wrist_pain': '손목',
      'fatigue': '피로',
    };
    final summaries = labels.entries
        .where((entry) => (condition[entry.key] as num? ?? 0) >= 4)
        .map((entry) => '${entry.value} 높음')
        .toList(growable: false);
    return summaries.isEmpty ? '특별히 불편한 항목 없음' : summaries.join(' · ');
  }
}
