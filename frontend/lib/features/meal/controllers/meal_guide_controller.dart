import 'package:flutter/foundation.dart';

import '../data/meal_selection_store.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';

enum MealGuideViewState { loading, ready, error }

class MealGuideController extends ChangeNotifier {
  MealGuideController({required this.service, MealSelectionStore? store})
    : store = store ?? MealSelectionStore.instance;

  final MealService service;
  final MealSelectionStore store;

  MealGuideViewState _state = MealGuideViewState.loading;
  MealGuideData? _data;
  MealPeriod? _selectedPeriod;
  bool _showDetails = false;

  MealGuideViewState get state => _state;
  MealGuideData? get data => _data;
  MealPeriod? get selectedPeriod => _selectedPeriod;
  bool get showDetails => _showDetails;
  MealDecision get selectedDecision {
    final recommendation = selectedRecommendation;
    return recommendation == null
        ? MealDecision.undecided
        : store.decisionFor(recommendation.id);
  }

  bool get selectedIsShared {
    final recommendation = selectedRecommendation;
    return recommendation != null && store.isShared(recommendation.id);
  }

  MealRecommendation? get selectedRecommendation {
    final period = _selectedPeriod;
    final guide = _data;
    if (period == null || guide == null) return null;
    final applied = store.appliedRecommendation;
    if (applied?.period == period) return applied;
    return guide.recommendationFor(period);
  }

  /// Mock/API 교체와 무관하게 화면은 동일한 Loading/Ready/Error 상태를 사용한다.
  Future<void> load() async {
    _state = MealGuideViewState.loading;
    notifyListeners();
    try {
      _data = await service.fetchGuide();
      _selectedPeriod = store.selectedPeriod;
      _showDetails = store.appliedRecommendation != null;
      _state = MealGuideViewState.ready;
    } on Object {
      _state = MealGuideViewState.error;
    }
    notifyListeners();
  }

  void selectPeriod(MealPeriod period) {
    store.selectPeriod(period);
    _selectedPeriod = period;
    _showDetails = true;
    notifyListeners();
  }

  void showPeriodList() {
    _showDetails = false;
    notifyListeners();
  }

  void showAppliedRecommendation() {
    final period = store.selectedPeriod;
    if (period == null || store.appliedRecommendation == null) return;
    _selectedPeriod = period;
    _showDetails = true;
    notifyListeners();
  }

  void acceptSelected() {
    final recommendation = selectedRecommendation;
    if (recommendation == null) return;
    store.recordDecision(recommendation.id, MealDecision.accepted);
    notifyListeners();
  }

  void rejectSelected() {
    final recommendation = selectedRecommendation;
    if (recommendation == null) return;
    store.recordDecision(recommendation.id, MealDecision.rejected);
    notifyListeners();
  }

  void shareSelected() {
    final recommendation = selectedRecommendation;
    if (recommendation == null) return;
    store.shareRecommendation(recommendation.id);
    notifyListeners();
  }
}
