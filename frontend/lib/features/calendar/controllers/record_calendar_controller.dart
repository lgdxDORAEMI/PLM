import 'package:flutter/foundation.dart';

import '../../report/models/daily_record.dart';
import '../../report/services/record_service.dart';

enum RecordCalendarViewState { loading, ready, error }

class RecordCalendarController extends ChangeNotifier {
  RecordCalendarController({required this.service});

  final RecordService service;
  RecordCalendarViewState _state = RecordCalendarViewState.loading;
  DateTime _visibleMonth = DateTime(2026, 9);
  DateTime _selectedDate = DateTime(2026, 9, 13);
  List<DailyRecord> _records = const [];

  RecordCalendarViewState get state => _state;
  DateTime get visibleMonth => _visibleMonth;
  DateTime get selectedDate => _selectedDate;
  List<DailyRecord> get records => List.unmodifiable(_records);
  DailyRecord? get selectedRecord => recordFor(_selectedDate);
  bool get canGoNext => _visibleMonth.isBefore(DateTime(2026, 9));

  DailyRecord? recordFor(DateTime date) {
    for (final record in _records) {
      if (recordDateKey(record.date) == recordDateKey(date)) return record;
    }
    return null;
  }

  Future<void> load() => _loadMonth(_visibleMonth, preferredDay: 13);

  Future<void> previousMonth() async {
    await _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1));
  }

  Future<void> nextMonth() async {
    if (!canGoNext) return;
    await _loadMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1));
  }

  void selectDate(DateTime date) {
    if (recordFor(date) == null) return;
    _selectedDate = date;
    notifyListeners();
  }

  /// 월을 바꾸면 기록이 있는 가장 최근 날짜를 기본 선택한다.
  Future<void> _loadMonth(DateTime month, {int? preferredDay}) async {
    _state = RecordCalendarViewState.loading;
    notifyListeners();
    try {
      final loaded = await service.fetchMonth(month);
      _visibleMonth = DateTime(month.year, month.month);
      _records = loaded;
      final preferred = preferredDay == null
          ? null
          : recordFor(DateTime(month.year, month.month, preferredDay));
      if (preferred != null) {
        _selectedDate = preferred.date;
      } else if (loaded.isNotEmpty) {
        _selectedDate = loaded.last.date;
      }
      _state = RecordCalendarViewState.ready;
    } on Object {
      _state = RecordCalendarViewState.error;
    }
    notifyListeners();
  }
}
