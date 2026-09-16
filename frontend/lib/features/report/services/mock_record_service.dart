import '../../partner/data/partner_request_store.dart';
import '../models/daily_record.dart';
import 'record_service.dart';

class MockRecordService implements RecordService {
  const MockRecordService();

  static final List<DailyRecord> records = [
    for (var day = 1; day <= 13; day++) _recordFor(day),
    _recordFor(29, month: 8),
    if (DateTime.now().year != 2026 ||
        DateTime.now().month != 9 ||
        DateTime.now().day > 13)
      _recordFor(
        DateTime.now().day,
        month: DateTime.now().month,
        year: DateTime.now().year,
      ),
  ];

  static DailyRecord _recordFor(int day, {int month = 9, int year = 2026}) {
    final level = switch (day % 4) {
      0 => ConditionLevel.difficult,
      1 => ConditionLevel.normal,
      2 => ConditionLevel.good,
      _ => ConditionLevel.bad,
    };
    final isSelectedMock = day == 13 && month == 9;
    return DailyRecord(
      date: DateTime(year, month, day),
      pregnancyWeek: month == 9 ? 28 : 26,
      conditionLevel: isSelectedMock ? ConditionLevel.difficult : level,
      conditionSummary: isSelectedMock
          ? '입덧 심함 · 허리 통증 심함 · 피로 심함'
          : switch (level) {
              ConditionLevel.good => '입덧 없음 · 통증 낮음 · 피로 낮음',
              ConditionLevel.normal => '입덧 보통 · 허리 통증 보통',
              ConditionLevel.bad => '입덧 있음 · 골반 통증 있음 · 피로 높음',
              ConditionLevel.difficult => '입덧 심함 · 허리 통증 심함 · 피로 심함',
            },
      completedRoutines: isSelectedMock ? 9 : 6 + day % 5,
      totalRoutines: 11,
      applianceSummary: isSelectedMock ? '로봇청소기 · 건조기 · 조명 · 온도' : '조명 · 온도',
      applianceCount: isSelectedMock ? 4 : 2,
      burdenArea: '허리',
      burdenCount: isSelectedMock ? 2 : 0,
      familyRequested: isSelectedMock ? 3 : 1,
      familyConfirmed: isSelectedMock ? 3 : 1,
      familyCompleted: isSelectedMock ? 2 : day % 2,
      routines: const [
        RoutineRecord(
          title: '달걀죽 + 부드러운 채소',
          category: RecordCategory.meal,
          status: RoutineRecordStatus.completed,
        ),
        RoutineRecord(
          title: '장보기 · 무거운 것 옮기기',
          category: RecordCategory.household,
          status: RoutineRecordStatus.completed,
          completedByPartner: true,
        ),
        RoutineRecord(
          title: '식탁 위 정리',
          category: RecordCategory.household,
          status: RoutineRecordStatus.completed,
          completedByPartner: true,
        ),
        RoutineRecord(
          title: '로봇청소기 · 거실 25분',
          category: RecordCategory.household,
          status: RoutineRecordStatus.completed,
        ),
        RoutineRecord(
          title: '골반 흔들기 스트레칭 5분',
          category: RecordCategory.health,
          status: RoutineRecordStatus.completed,
        ),
        RoutineRecord(
          title: '수면 루틴 실행 (조명 · 온도 · 소리)',
          category: RecordCategory.sleep,
          status: RoutineRecordStatus.completed,
        ),
        RoutineRecord(
          title: '설거지 — 식기세척기',
          category: RecordCategory.household,
          status: RoutineRecordStatus.skipped,
        ),
      ],
    );
  }

  @override
  Future<List<DailyRecord>> fetchMonth(DateTime month) async => records
      .where(
        (record) =>
            record.date.year == month.year && record.date.month == month.month,
      )
      .map(_withPartnerSummary)
      .toList(growable: false);

  @override
  Future<DailyRecord?> fetchRecord(DateTime date) async {
    final normalized = date.year == 0 ? DateTime(2026, 9, 13) : date;
    for (final record in records) {
      if (recordDateKey(record.date) == recordDateKey(normalized)) {
        return _withPartnerSummary(record);
      }
    }
    return null;
  }

  @override
  Future<void> saveRecord(DailyRecord record) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> shareRecord(DailyRecord record) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  /// Partner Request 처리 상태를 Calendar와 Report의 가족 분담 집계에 합성한다.
  DailyRecord _withPartnerSummary(DailyRecord record) {
    final summary = PartnerRequestStore.instance.summaryFor(
      recordDateKey(record.date),
    );
    if (summary == null) return record;
    return record.copyWithFamilySummary(
      requested: summary.requested,
      confirmed: summary.confirmed,
      completed: summary.completed,
    );
  }
}
