import '../models/condition_draft.dart';
import 'condition_repository.dart';

/// Backend 없이(Mock Service 단계) 프로세스 메모리에만 저장하는 구현. 실제
/// Supabase `daily_conditions` 테이블 구조를 전혀 모른다 — 그냥 날짜별 Map이다.
class MockConditionRepository implements ConditionRepository {
  final Map<String, ConditionDraft> _byDate = {};

  @override
  Future<ConditionDraft?> fetchToday(DateTime date) async => _byDate[_key(date)];

  @override
  Future<void> saveToday(DateTime date, ConditionDraft draft) async {
    _byDate[_key(date)] = draft;
  }

  String _key(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
