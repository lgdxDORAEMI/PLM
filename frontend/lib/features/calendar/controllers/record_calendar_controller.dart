import 'dart:async';

import 'package:flutter/material.dart';

import '../../report/models/daily_record.dart';
import '../../report/services/record_service.dart';

/// notShared(09-29): 남편 화면인데 아내가 아직 기록을 공개하지 않았다.
enum RecordCalendarViewState {
  initialLoading,
  ready,
  refreshing,
  error,
  notShared,
}

enum RecordCalendarDetailState { idle, loading, ready, empty, error }

class RecordCalendarController extends ChangeNotifier {
  RecordCalendarController({
    required this.service,
    DateTime? initialSelectedDate,
    this.onSelected,
    this.selectsTodayWithoutRecord = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _visibleMonth = DateTime(
         initialSelectedDate?.year ?? 2026,
         initialSelectedDate?.month ?? 9,
       ),
       _selectedDate = initialSelectedDate ?? DateTime(2026, 9, 13);

  final RecordService service;
  final ValueChanged<DateTime>? onSelected;

  /// 09-29: 남편 화면. 오늘 컨디션이 아직 없어도 오늘을 선택해 날짜·주차를 보여준다.
  final bool selectsTodayWithoutRecord;
  final DateTime Function() _clock;
  RecordCalendarViewState _state = RecordCalendarViewState.initialLoading;
  RecordCalendarDetailState _detailState = RecordCalendarDetailState.idle;
  DateTime _visibleMonth;
  DateTime _selectedDate;
  List<DailyRecord> _records = const [];
  final Map<String, DailyRecord> _detailsByDate = {};
  int _monthRequestId = 0;
  int _detailRequestId = 0;
  bool _monthRefreshFailed = false;
  bool _disposed = false;

  RecordCalendarViewState get state => _state;
  RecordCalendarDetailState get detailState => _detailState;
  DateTime get visibleMonth => _visibleMonth;
  DateTime get selectedDate => _selectedDate;
  List<DailyRecord> get records => List.unmodifiable(_records);
  DailyRecord? get selectedRecord =>
      _detailsByDate[recordDateKey(_selectedDate)] ?? recordFor(_selectedDate);
  bool get selectedDetailsLoading =>
      _detailState == RecordCalendarDetailState.loading;
  bool get monthRefreshFailed => _monthRefreshFailed;
  bool get canGoNext => _visibleMonth.isBefore(
    DateTime(DateTime.now().year, DateTime.now().month),
  );

  DateTime get _today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// 기록이 없어도 고를 수 있는 날짜(남편 화면의 오늘). 없으면 null.
  DateTime? get emptySelectableDate =>
      selectsTodayWithoutRecord ? _today : null;

  bool _canSelect(DateTime date) =>
      recordFor(date) != null ||
      (selectsTodayWithoutRecord && DateUtils.isSameDay(date, _today));

  DailyRecord? recordFor(DateTime date) {
    for (final record in _records) {
      if (recordDateKey(record.date) == recordDateKey(date)) return record;
    }
    return null;
  }

  Future<void> load() =>
      _loadMonth(_visibleMonth, preferredDay: _selectedDate.day);

  /// 화면 복귀 시 기존 값을 유지하면서 월 목록과 선택 날짜를 갱신한다.
  Future<void> refresh() => _loadMonth(
    _visibleMonth,
    preferredDay: _selectedDate.day,
    refreshSelectedDetails: true,
  );

  Future<void> previousMonth() =>
      _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1));

  Future<void> nextMonth() async {
    if (!canGoNext) return;
    await _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1));
  }

  Future<void> selectDate(DateTime date) async {
    if (!_canSelect(date)) return;
    _selectedDate = date;
    onSelected?.call(date);
    final cached = _detailsByDate.containsKey(recordDateKey(date));
    _detailState = cached
        ? RecordCalendarDetailState.ready
        : RecordCalendarDetailState.loading;
    _notify();
    if (!cached) await _loadDetails(date);
  }

  Future<void> retrySelectedDetails() =>
      _loadDetails(_selectedDate, force: true);

  /// 선택 날짜가 바뀌는 동안 이전 요청의 늦은 응답은 화면에 반영하지 않는다.
  Future<void> _loadDetails(DateTime date, {bool force = false}) async {
    final key = recordDateKey(date);
    final cached = _detailsByDate.containsKey(key);
    if (cached && !force) {
      _detailState = RecordCalendarDetailState.ready;
      _notify();
      return;
    }

    final requestId = ++_detailRequestId;
    if (!cached) _detailState = RecordCalendarDetailState.loading;
    _notify();
    try {
      final loaded = await service.fetchCalendarRecord(date);
      if (!_isCurrentDetailRequest(requestId, key)) return;
      // 아내 화면은 컨디션 없는 날을 예전처럼 "기록 없음"으로 다룬다.
      if (loaded == null ||
          (loaded.awaitingCondition && !selectsTodayWithoutRecord)) {
        _detailState = RecordCalendarDetailState.empty;
      } else {
        _detailsByDate[key] = loaded;
        _detailState = RecordCalendarDetailState.ready;
      }
    } on PartnerRecordNotSharedException {
      if (_disposed) return;
      _markNotShared();
      return;
    } on Object {
      if (!_isCurrentDetailRequest(requestId, key)) return;
      _detailState = cached
          ? RecordCalendarDetailState.ready
          : RecordCalendarDetailState.error;
    }
    _notify();
  }

  bool _isCurrentDetailRequest(int requestId, String dateKey) =>
      !_disposed &&
      requestId == _detailRequestId &&
      recordDateKey(_selectedDate) == dateKey;

  /// 월 목록과 상세 조회를 분리해 월 응답이 오면 캘린더부터 표시한다.
  Future<void> _loadMonth(
    DateTime month, {
    int? preferredDay,
    bool refreshSelectedDetails = false,
  }) async {
    final requestId = ++_monthRequestId;
    final hasVisibleData =
        _state != RecordCalendarViewState.initialLoading &&
        _state != RecordCalendarViewState.error &&
        _state != RecordCalendarViewState.notShared;
    _state = hasVisibleData
        ? RecordCalendarViewState.refreshing
        : RecordCalendarViewState.initialLoading;
    _monthRefreshFailed = false;
    _notify();

    try {
      final loaded = await service.fetchMonth(month);
      if (_disposed || requestId != _monthRequestId) return;

      // 기존 월을 표시하는 동안 진행 중인 상세 조회는 그대로 허용하고,
      // 새 월을 실제 반영하는 시점부터 이전 상세 응답만 무효화한다.
      ++_detailRequestId;
      _visibleMonth = DateTime(month.year, month.month);
      _records = loaded;
      final preferred = preferredDay == null
          ? null
          : recordFor(DateTime(month.year, month.month, preferredDay));
      final showsToday =
          selectsTodayWithoutRecord &&
          month.year == _today.year &&
          month.month == _today.month;
      if (preferred != null) {
        _selectedDate = preferred.date;
      } else if (showsToday) {
        _selectedDate = _today;
      } else if (loaded.isNotEmpty) {
        _selectedDate = loaded.last.date;
      }
      _state = RecordCalendarViewState.ready;

      if (!_canSelect(_selectedDate)) {
        _detailState = RecordCalendarDetailState.idle;
        _notify();
        return;
      }

      final hasCachedDetails = _detailsByDate.containsKey(
        recordDateKey(_selectedDate),
      );
      _detailState = hasCachedDetails
          ? RecordCalendarDetailState.ready
          : RecordCalendarDetailState.loading;
      _notify();
      unawaited(
        _loadDetails(
          _selectedDate,
          force: refreshSelectedDetails && hasCachedDetails,
        ),
      );
    } on PartnerRecordNotSharedException {
      if (_disposed || requestId != _monthRequestId) return;
      _markNotShared();
    } on Object {
      if (_disposed || requestId != _monthRequestId) return;
      if (hasVisibleData) {
        _state = RecordCalendarViewState.ready;
        _monthRefreshFailed = true;
      } else {
        _state = RecordCalendarViewState.error;
      }
      _notify();
    }
  }

  void _markNotShared() {
    _records = const [];
    _detailsByDate.clear();
    _state = RecordCalendarViewState.notShared;
    _detailState = RecordCalendarDetailState.idle;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_monthRequestId;
    ++_detailRequestId;
    super.dispose();
  }
}
