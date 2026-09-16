import 'package:flutter/foundation.dart';

import '../models/meal_guide.dart';

/// Meal Guide와 재추천 화면 사이의 선택 결과만 메모리에 보관한다.
class MealSelectionStore extends ChangeNotifier {
  MealSelectionStore._();

  static final MealSelectionStore instance = MealSelectionStore._();

  MealPeriod? _selectedPeriod;
  MealRecommendation? _appliedRecommendation;
  final Map<String, MealDecision> _decisions = {};
  final Set<String> _sharedRecommendationIds = {};

  MealPeriod? get selectedPeriod => _selectedPeriod;
  MealRecommendation? get appliedRecommendation => _appliedRecommendation;

  MealDecision decisionFor(String recommendationId) =>
      _decisions[recommendationId] ?? MealDecision.undecided;

  bool isShared(String recommendationId) =>
      _sharedRecommendationIds.contains(recommendationId);

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

  void recordDecision(String recommendationId, MealDecision decision) {
    _decisions[recommendationId] = decision;
    notifyListeners();
  }

  void shareRecommendation(String recommendationId) {
    _sharedRecommendationIds.add(recommendationId);
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _selectedPeriod = null;
    _appliedRecommendation = null;
    _decisions.clear();
    _sharedRecommendationIds.clear();
    notifyListeners();
  }
}
