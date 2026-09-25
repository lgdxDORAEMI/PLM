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
  final Set<MealPeriod> _replacementPeriods = {};
  bool _showDetails = false;
  bool _loadingAlternative = false;

  MealGuideViewState get state => _state;

  /// '다른 메뉴 보기'로 새 메뉴를 받아오는 중(3~4초). 화면은 버튼을 잠근다.
  bool get loadingAlternative => _loadingAlternative;
  MealGuideData? get data => _data;
  List<MealPeriodSummary> get periodSummaries {
    final guide = _data;
    if (guide == null) return const [];
    return [
      for (final summary in guide.periods)
        MealPeriodSummary(
          period: summary.period,
          label: summary.label,
          summary:
              _selectedRecommendations[summary.period]?.title ??
              summary.summary,
          isCurrent: summary.isCurrent,
          imageUrl:
              _selectedRecommendations[summary.period]?.imageUrl ??
              summary.imageUrl,
        ),
    ];
  }

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
        404 => MealGuideViewState.empty,
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

  Future<void> acceptSelected() async {
    final recommendation = selectedRecommendation;
    final period = _selectedPeriod;
    if (recommendation == null || period == null) return;
    final previous = store.decisionFor(recommendation.id);
    try {
      if (_replacementPeriods.contains(period)) {
        await service.replaceRecommendation(recommendation);
      } else {
        await service.recordDecision(recommendation, MealDecision.accepted);
      }
      store.recordDecision(recommendation.id, MealDecision.accepted);
      store.applyRecommendation(recommendation);
      _selectedRecommendations[period] = recommendation;
      notifyListeners();
    } on Object {
      store.recordDecision(recommendation.id, previous);
      _state = MealGuideViewState.error;
      notifyListeners();
    }
  }

  void rejectSelected() {
    final recommendation = selectedRecommendation;
    if (recommendation == null) return;
    store.recordDecision(recommendation.id, MealDecision.rejected);
    notifyListeners();
  }

  /// 현재 추천에 대한 거절을 기록한 뒤 사용 가능한 다음 메뉴를 보여준다.
  Future<void> showNextRecommendation() async {
    final period = _selectedPeriod;
    final guide = _data;
    final current = selectedRecommendation;
    if (period == null || guide == null || current == null) return;

    final recommendations = guide.recommendationsFor(period);
    try {
      await service.recordDecision(current, MealDecision.rejected);
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        404 => MealGuideViewState.empty,
        401 || 403 => MealGuideViewState.authError,
        409 || 422 => MealGuideViewState.domainError,
        503 => MealGuideViewState.serverError,
        _ => MealGuideViewState.error,
      };
      notifyListeners();
      return;
    } on Object {
      _state = MealGuideViewState.error;
      notifyListeners();
      return;
    }

    store.recordDecision(current.id, MealDecision.rejected);
    if (recommendations.length < 2) {
      // 실제 루틴은 끼니당 메뉴가 1개라 순환할 후보가 없다 → Backend에 새 메뉴 1개를 요청한다(09-22).
      await _loadAlternative(period, current);
      return;
    }
    final currentIndex = recommendations.indexWhere(
      (recommendation) => recommendation.id == current.id,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % recommendations.length;
    _selectedRecommendations[period] = recommendations[nextIndex];
    _replacementPeriods.add(period);
    notifyListeners();
  }

  Future<void> _loadAlternative(
    MealPeriod period,
    MealRecommendation current,
  ) async {
    if (_loadingAlternative) return;
    _loadingAlternative = true;
    notifyListeners();
    try {
      final next = await service.fetchAlternative(
        current: current,
        request: '다른 메뉴 보기',
      );
      _selectedRecommendations[period] = next;
      _replacementPeriods.add(period);
      // 새 메뉴는 아직 고르지 않은 상태다(같은 끼니 id라 직전 거절 표시가 남지 않게 되돌린다).
      store.recordDecision(next.id, MealDecision.undecided);
    } on Object {
      // 새 메뉴를 못 받으면 지금 메뉴를 그대로 보여준다. 거절 기록은 이미 남았다.
    } finally {
      _loadingAlternative = false;
      notifyListeners();
    }
  }
}
