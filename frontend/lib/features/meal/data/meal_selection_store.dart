import 'package:flutter/foundation.dart';

import '../models/meal_guide.dart';

/// Meal Guide와 재추천 화면 사이의 선택 결과만 메모리에 보관한다.
class MealSelectionStore extends ChangeNotifier {
  MealSelectionStore._();

  static final MealSelectionStore instance = MealSelectionStore._();

  MealPeriod? _selectedPeriod;
  MealRecommendation? _appliedRecommendation;

  MealPeriod? get selectedPeriod => _selectedPeriod;
  MealRecommendation? get appliedRecommendation => _appliedRecommendation;

  void selectPeriod(MealPeriod period) {
    _selectedPeriod = period;
    _appliedRecommendation = null;
    notifyListeners();
  }

  void applyRecommendation(MealRecommendation recommendation) {
    _selectedPeriod = recommendation.period;
    _appliedRecommendation = recommendation;
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _selectedPeriod = null;
    _appliedRecommendation = null;
    notifyListeners();
  }
}
