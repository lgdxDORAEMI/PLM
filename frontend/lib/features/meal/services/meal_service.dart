import '../models/meal_guide.dart';

abstract interface class MealService {
  Future<MealGuideData> fetchGuide();

  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  );

  /// 사용자가 '다른 메뉴 보기'에서 고른 메뉴를 오늘의 선택으로 저장한다.
  Future<void> replaceRecommendation(MealRecommendation recommendation);

  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  });
}
