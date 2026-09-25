import '../models/daily_record.dart';

abstract interface class RecordService {
  Future<List<DailyRecord>> fetchMonth(DateTime month);
  Future<DailyRecord?> fetchCalendarRecord(DateTime date);
  Future<DailyRecord?> fetchRecord(DateTime date);
  Future<void> saveRecord(DailyRecord record);
  Future<void> shareRecord(DailyRecord record);
}
