import '../models/meal_guide.dart';

abstract interface class MealService {
  Future<MealGuideData> fetchGuide();

  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  );

  /// 사용자가 '다른 메뉴 보기'에서 고른 메뉴를 오늘의 선택으로 저장한다.
  Future<void> replaceRecommendation(MealRecommendation recommendation);

  /// 홈 화면 '루틴 진행도'가 읽는 routine_items 실행 상태를 갱신한다
  /// (건강 가이드의 ApiHealthGuideService.setCompleted와 같은 역할).
  Future<void> setCompleted(String itemId, bool completed);

  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  });
}
