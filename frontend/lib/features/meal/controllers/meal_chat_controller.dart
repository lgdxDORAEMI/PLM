import 'package:flutter/foundation.dart';

import '../data/meal_selection_store.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';

class MealChatController extends ChangeNotifier {
  MealChatController({required this.service, MealSelectionStore? store})
    : store = store ?? MealSelectionStore.instance;

  final MealService service;
  final MealSelectionStore store;

  MealRecommendation? _current;
  MealRecommendation? _proposal;
  String _request = '속이 좀 메스꺼워요';
  bool _responding = false;

  MealRecommendation? get current => _current;
  MealRecommendation? get proposal => _proposal;
  String get request => _request;
  bool get responding => _responding;

  void initialize(MealRecommendation fallback) {
    _current = store.appliedRecommendation ?? fallback;
  }

  /// 현재 Meal 맥락만 Service에 전달해 식사 외 재조정으로 범위가 확장되지 않게 한다.
  Future<void> requestAlternative(String value) async {
    final currentMeal = _current;
    final normalized = value.trim();
    if (currentMeal == null || normalized.isEmpty || _responding) return;
    _request = normalized;
    _responding = true;
    notifyListeners();
    _proposal = await service.fetchAlternative(
      current: currentMeal,
      request: normalized,
    );
    _responding = false;
    notifyListeners();
  }

  void applyProposal() {
    final value = _proposal;
    if (value == null) return;
    store.applyRecommendation(value);
  }
}
