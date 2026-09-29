import '../models/daily_record.dart';

/// 09-29: 남편이 조회했지만 아내가 아직 기록을 공개하지 않았다(초기화 후 초대 확인 전).
class PartnerRecordNotSharedException implements Exception {
  const PartnerRecordNotSharedException();
}

abstract interface class RecordService {
  Future<List<DailyRecord>> fetchMonth(DateTime month);
  Future<DailyRecord?> fetchCalendarRecord(DateTime date);
  Future<DailyRecord?> fetchRecord(DateTime date);
  Future<void> saveRecord(DailyRecord record);
  Future<void> shareRecord(DailyRecord record);
}
