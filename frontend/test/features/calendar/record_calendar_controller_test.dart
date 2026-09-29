import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/calendar/controllers/record_calendar_controller.dart';
import 'package:plm_frontend/features/report/models/daily_record.dart';
import 'package:plm_frontend/features/report/services/record_service.dart';

void main() {
  group('남편 화면(09-29)', () {
    DateTime clock() => DateTime(2026, 9, 29, 10);

    test('오늘 컨디션이 없어도 전날이 아니라 오늘을 선택하고 주차를 보여준다', () async {
      final service = _TestRecordService(
        fetchMonthHandler: (_) async => [_record(28)],
        fetchRecordHandler: (date) async =>
            DailyRecord.awaitingCondition(date: date, pregnancyWeek: 20),
      );
      final controller = RecordCalendarController(
        service: service,
        initialSelectedDate: clock(),
        selectsTodayWithoutRecord: true,
        clock: clock,
      );

      await controller.load();
      await _flushAsync();

      expect(controller.selectedDate, DateTime(2026, 9, 29));
      expect(controller.selectedRecord?.awaitingCondition, isTrue);
      expect(controller.selectedRecord?.pregnancyWeek, 20);
    });

    test('아내가 공개하지 않았으면 notShared 상태가 되고 기록을 비운다', () async {
      final service = _TestRecordService(
        fetchMonthHandler: (_) async =>
            throw const PartnerRecordNotSharedException(),
        fetchRecordHandler: (_) async => null,
      );
      final controller = RecordCalendarController(
        service: service,
        initialSelectedDate: clock(),
        selectsTodayWithoutRecord: true,
        clock: clock,
      );

      await controller.load();

      expect(controller.state, RecordCalendarViewState.notShared);
      expect(controller.records, isEmpty);
    });
  });

  test('아내 화면은 컨디션 없는 날을 예전처럼 기록 없음으로 다룬다', () async {
    final service = _TestRecordService(
      fetchMonthHandler: (_) async => [_record(13)],
      fetchRecordHandler: (date) async =>
          DailyRecord.awaitingCondition(date: date, pregnancyWeek: 20),
    );
    final controller = RecordCalendarController(service: service);

    await controller.load();
    await _flushAsync();

    expect(controller.detailState, RecordCalendarDetailState.empty);
  });

  test('월 응답이 오면 상세 응답을 기다리지 않고 캘린더를 표시한다', () async {
    final detail = Completer<DailyRecord?>();
    final service = _TestRecordService(
      fetchMonthHandler: (_) async => [_record(13)],
      fetchRecordHandler: (_) => detail.future,
    );
    final controller = RecordCalendarController(service: service);

    await controller.load();

    expect(controller.state, RecordCalendarViewState.ready);
    expect(controller.records, hasLength(1));
    expect(controller.detailState, RecordCalendarDetailState.loading);
    detail.complete(_record(13, summary: '상세 컨디션'));
    await _flushAsync();
    expect(controller.selectedRecord?.conditionSummary, '상세 컨디션');
  });

  test('늦게 도착한 이전 월 응답이 최신 월을 덮지 않는다', () async {
    final august = Completer<List<DailyRecord>>();
    final september = Completer<List<DailyRecord>>();
    final service = _TestRecordService(
      fetchMonthHandler: (month) =>
          month.month == 8 ? august.future : september.future,
      fetchRecordHandler: (date) async => _record(date.day, month: date.month),
    );
    final controller = RecordCalendarController(service: service);

    final oldRequest = controller.previousMonth();
    final latestRequest = controller.load();
    september.complete([_record(13)]);
    await latestRequest;
    august.complete([_record(29, month: 8)]);
    await oldRequest;

    expect(controller.visibleMonth.month, 9);
    expect(controller.records.single.date.month, 9);
  });

  test('빠르게 날짜를 바꾸면 마지막 날짜의 상세만 반영한다', () async {
    final details = <int, Completer<DailyRecord?>>{
      7: Completer<DailyRecord?>(),
      8: Completer<DailyRecord?>(),
    };
    final service = _TestRecordService(
      fetchMonthHandler: (_) async => [_record(7), _record(8), _record(13)],
      fetchRecordHandler: (date) {
        if (date.day == 13) return Future.value(_record(13));
        return details[date.day]!.future;
      },
    );
    final controller = RecordCalendarController(service: service);
    await controller.load();
    await _flushAsync();

    final oldRequest = controller.selectDate(DateTime(2026, 9, 7));
    final latestRequest = controller.selectDate(DateTime(2026, 9, 8));
    details[8]!.complete(_record(8, summary: '8일 상세'));
    await latestRequest;
    details[7]!.complete(_record(7, summary: '7일 상세'));
    await oldRequest;

    expect(controller.selectedDate.day, 8);
    expect(controller.selectedRecord?.conditionSummary, '8일 상세');
  });

  test('새로고침 중과 실패 후에도 기존 월 기록을 유지한다', () async {
    var callCount = 0;
    final refresh = Completer<List<DailyRecord>>();
    final service = _TestRecordService(
      fetchMonthHandler: (_) {
        callCount++;
        return callCount == 1 ? Future.value([_record(13)]) : refresh.future;
      },
      fetchRecordHandler: (date) async => _record(date.day),
    );
    final controller = RecordCalendarController(service: service);
    await controller.load();
    await _flushAsync();

    final pending = controller.refresh();
    expect(controller.state, RecordCalendarViewState.refreshing);
    expect(controller.records, hasLength(1));
    refresh.completeError(StateError('network'));
    await pending;

    expect(controller.state, RecordCalendarViewState.ready);
    expect(controller.records, hasLength(1));
    expect(controller.monthRefreshFailed, isTrue);
  });

  test('상세 조회 실패를 오류 상태로 표시하고 월 기록은 유지한다', () async {
    final service = _TestRecordService(
      fetchMonthHandler: (_) async => [_record(13)],
      fetchRecordHandler: (_) => Future.error(StateError('network')),
    );
    final controller = RecordCalendarController(service: service);

    await controller.load();
    await _flushAsync();

    expect(controller.state, RecordCalendarViewState.ready);
    expect(controller.records, hasLength(1));
    expect(controller.detailState, RecordCalendarDetailState.error);
  });
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

DailyRecord _record(int day, {int month = 9, String summary = '월 컨디션'}) =>
    DailyRecord(
      date: DateTime(2026, month, day),
      pregnancyWeek: 28,
      conditionLevel: ConditionLevel.normal,
      conditionSummary: summary,
      completedRoutines: 0,
      totalRoutines: 0,
      applianceSummary: '실행 기록 없음',
      applianceCount: 0,
      routines: const [],
      familyRequested: 0,
      familyConfirmed: 0,
      familyCompleted: 0,
    );

class _TestRecordService implements RecordService {
  const _TestRecordService({
    required this.fetchMonthHandler,
    required this.fetchRecordHandler,
  });

  final Future<List<DailyRecord>> Function(DateTime month) fetchMonthHandler;
  final Future<DailyRecord?> Function(DateTime date) fetchRecordHandler;

  @override
  Future<List<DailyRecord>> fetchMonth(DateTime month) =>
      fetchMonthHandler(month);

  @override
  Future<DailyRecord?> fetchCalendarRecord(DateTime date) =>
      fetchRecordHandler(date);

  @override
  Future<DailyRecord?> fetchRecord(DateTime date) => fetchRecordHandler(date);

  @override
  Future<void> saveRecord(DailyRecord record) async {}

  @override
  Future<void> shareRecord(DailyRecord record) async {}
}
