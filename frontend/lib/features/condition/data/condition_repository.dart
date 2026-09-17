import '../models/condition_draft.dart';

/// `TodayCareStore`가 당일 컨디션을 어디서 읽고/쓰는지를 추상화한다.
///
/// Mock(`MockConditionRepository`)과 API(`ApiConditionRepository`) 구현이
/// 이 인터페이스 하나를 공유한다 — 화면·Controller는 어느 쪽이 주입됐는지
/// 모른다(STEP 15). Backend 계약은 `docs/backend/API_CONTRACT.md`의
/// `GET/PUT /api/v1/care/conditions/{date}` 참고.
abstract class ConditionRepository {
  Future<ConditionDraft?> fetchToday(DateTime date);

  Future<void> saveToday(DateTime date, ConditionDraft draft);
}
