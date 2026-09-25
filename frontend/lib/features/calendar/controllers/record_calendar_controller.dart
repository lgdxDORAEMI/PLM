import 'package:flutter/foundation.dart';

import '../../report/models/daily_record.dart';
import '../../report/services/record_service.dart';

enum RecordCalendarViewState { loading, ready, error }

class RecordCalendarController extends ChangeNotifier {
  RecordCalendarController({
    required this.service,
    DateTime? initialSelectedDate,
    this.onSelected,
  }) : _visibleMonth = DateTime(
         initialSelectedDate?.year ?? 2026,
         initialSelectedDate?.month ?? 9,
       ),
       _selectedDate = initialSelectedDate ?? DateTime(2026, 9, 13);

  final RecordService service;
  final ValueChanged<DateTime>? onSelected;
  RecordCalendarViewState _state = RecordCalendarViewState.loading;
  DateTime _visibleMonth;
  DateTime _selectedDate;
  List<DailyRecord> _records = const [];
  DailyRecord? _details;

  RecordCalendarViewState get state => _state;
  DateTime get visibleMonth => _visibleMonth;
  DateTime get selectedDate => _selectedDate;
  List<DailyRecord> get records => List.unmodifiable(_records);
  DailyRecord? get selectedRecord => _details ?? recordFor(_selectedDate);

  /// true면 [selectedRecord]가 fetchMonth()의 가벼운 껍데기 값(컨디션/루틴 수 0)이라
  /// 화면에 실제 값처럼 보여주면 안 된다 — fetchRecord() 상세 응답이 아직 안 왔다는 뜻.
  bool get selectedDetailsLoading => _details == null;
  bool get canGoNext => _visibleMonth.isBefore(
    DateTime(DateTime.now().year, DateTime.now().month),
  );

  DailyRecord? recordFor(DateTime date) {
    for (final record in _records) {
      if (recordDateKey(record.date) == recordDateKey(date)) return record;
    }
    return null;
  }

  Future<void> load() =>
      _loadMonth(_visibleMonth, preferredDay: _selectedDate.day);

  Future<void> previousMonth() async {
    await _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1));
  }

  Future<void> nextMonth() async {
    if (!canGoNext) return;
    await _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1));
  }

  Future<void> selectDate(DateTime date) async {
    if (recordFor(date) == null) return;
    _selectedDate = date;
    _details = null;
    onSelected?.call(date);
    notifyListeners();
    await _loadDetails(date);
  }

  /// Loads the selected day's full report only when its details are needed.
  Future<void> _loadDetails(DateTime date) async {
    try {
      final loaded = await service.fetchRecord(date);
      if (recordDateKey(_selectedDate) != recordDateKey(date)) return;
      _details = loaded;
      notifyListeners();
    } catch (_) {
      // Calendar markers remain usable even if one report cannot be read.
    }
  }

  /// 월을 바꾸면 기록이 있는 가장 최근 날짜를 기본 선택한다.
  Future<void> _loadMonth(DateTime month, {int? preferredDay}) async {
    _state = RecordCalendarViewState.loading;
    notifyListeners();
    try {
      final loaded = await service.fetchMonth(month);
      _visibleMonth = DateTime(month.year, month.month);
      _records = loaded;
      _details = null;
      final preferred = preferredDay == null
          ? null
          : recordFor(DateTime(month.year, month.month, preferredDay));
      if (preferred != null) {
        _selectedDate = preferred.date;
      } else if (loaded.isNotEmpty) {
        _selectedDate = loaded.last.date;
      }
      _state = RecordCalendarViewState.ready;
      if (recordFor(_selectedDate) != null) {
        await _loadDetails(_selectedDate);
      }
    } on Object {
      _state = RecordCalendarViewState.error;
    }
    notifyListeners();
  }
}
