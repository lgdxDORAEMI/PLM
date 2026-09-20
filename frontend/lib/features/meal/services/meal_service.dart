import '../models/meal_guide.dart';

abstract interface class MealService {
  Future<MealGuideData> fetchGuide();

  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  );

  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  });
}
