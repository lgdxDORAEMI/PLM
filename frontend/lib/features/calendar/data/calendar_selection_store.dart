/// Calendar와 Report 사이에서 선택한 날짜를 보존하는 세션 내 UI 상태다.
class CalendarSelectionStore {
  CalendarSelectionStore._();

  static final CalendarSelectionStore instance = CalendarSelectionStore._();

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  void remember(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
  }

  void reset() => _selectedDate = null;
}
