import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/meal_selection_store.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';

enum MealGuideViewState {
  loading,
  ready,
  empty,
  authError,
  domainError,
  serverError,
  error,
}

class MealGuideController extends ChangeNotifier {
  MealGuideController({
    required this.service,
    this.initialPeriod,
    MealSelectionStore? store,
  }) : store = store ?? MealSelectionStore.instance;

  final MealService service;
  final MealPeriod? initialPeriod;
  final MealSelectionStore store;

  MealGuideViewState _state = MealGuideViewState.loading;
  MealGuideData? _data;
  MealPeriod? _selectedPeriod;
  final Map<MealPeriod, MealRecommendation> _selectedRecommendations = {};
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

  MealRecommendation? get selectedRecommendation {
    final period = _selectedPeriod;
    final guide = _data;
    if (period == null || guide == null) return null;
    return _selectedRecommendations[period] ?? guide.recommendationFor(period);
  }

  /// 메뉴를 교체해도 최초 추천을 만든 컨디션 근거는 화면 상단에 유지한다.
  MealRecommendation? get recommendationContext {
    final period = _selectedPeriod;
    final guide = _data;
    if (period == null || guide == null) return null;
    return guide.recommendationFor(period);
  }

  /// Mock/API 교체와 무관하게 화면은 동일한 Loading/Ready/Error 상태를 사용한다.
  Future<void> load() async {
    _state = MealGuideViewState.loading;
    notifyListeners();
    try {
      _data = await service.fetchGuide();
      if (_data!.recommendations.isEmpty) {
        _state = MealGuideViewState.empty;
        notifyListeners();
        return;
      }
      final preferred = initialPeriod ?? store.selectedPeriod;
      _selectedPeriod = _data!.periods.any((entry) => entry.period == preferred)
          ? preferred
          : null;
      final applied = store.appliedRecommendation;
      if (applied != null) {
        _selectedRecommendations[applied.period] = applied;
      }
      _showDetails = initialPeriod != null || applied != null;
      _state = MealGuideViewState.ready;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => MealGuideViewState.authError,
        409 || 422 => MealGuideViewState.domainError,
        503 => MealGuideViewState.serverError,
        _ => MealGuideViewState.error,
      };
    } on Object {
      _state = MealGuideViewState.error;
    }
    notifyListeners();
  }

  void selectPeriod(MealPeriod period) {
    store.selectPeriod(period);
    _selectedPeriod = period;
    _selectedRecommendations.putIfAbsent(
      period,
      () => _data!.recommendationFor(period),
    );
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
    _selectedRecommendations[period] = store.appliedRecommendation!;
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

  /// 현재 끼니의 Mock 추천을 순환해 화면 안에서 다음 메뉴를 보여준다.
  void showNextRecommendation() {
    final period = _selectedPeriod;
    final guide = _data;
    final current = selectedRecommendation;
    if (period == null || guide == null || current == null) return;

    final recommendations = guide.recommendationsFor(period);
    if (recommendations.length < 2) return;

    store.recordDecision(current.id, MealDecision.rejected);
    final currentIndex = recommendations.indexWhere(
      (recommendation) => recommendation.id == current.id,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % recommendations.length;
    _selectedRecommendations[period] = recommendations[nextIndex];
    notifyListeners();
  }
}
