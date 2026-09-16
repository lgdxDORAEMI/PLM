import '../models/meal_guide.dart';

abstract interface class MealService {
  Future<MealGuideData> fetchGuide();

  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  });
}
