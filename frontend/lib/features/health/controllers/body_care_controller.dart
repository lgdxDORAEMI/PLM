import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../condition/data/today_care_store.dart';
import '../../condition/models/condition_draft.dart';
import '../models/body_care_guide.dart';
import '../services/health_guide_service.dart';

enum BodyCareViewState { loading, data, empty, authError, serverError, error }

class BodyCareController extends ChangeNotifier {
  BodyCareController({required this.service, TodayCareStore? conditionStore})
    : conditionStore = conditionStore ?? TodayCareStore.instance;

  final HealthGuideService service;
  final TodayCareStore conditionStore;
  final Set<String> _completed = {};
  BodyCareViewState _state = BodyCareViewState.loading;
  BodyCareGuideData? _guide;
  String? _selectedArea;

  BodyCareViewState get state => _state;
  List<BodyLoad> get loads {
    final condition = conditionStore.today;
    if (condition == null) {
      return (_guide?.loads ?? const [])
          .where((load) => load.value >= .5)
          .toList(growable: false);
    }
    final result = _conditionLoads(
      condition,
    ).where((load) => load.value >= .6).toList(growable: false);
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }

  List<BodyCareActivity> get activities => _guide?.activities ?? const [];
  List<String> get availableAreas => activities
      .map((activity) => activity.area)
      .toSet()
      .toList(growable: false);
  String get selectedArea => _selectedArea ?? '';
  bool isCompleted(String id) => _completed.contains(id);
  List<BodyCareActivity> get selectedActivities => activities
      .where((activity) => activity.area == selectedArea)
      .toList(growable: false);

  Future<void> load() async {
    _state = BodyCareViewState.loading;
    notifyListeners();
    try {
      await conditionStore.loadToday();
      _guide = await service.fetchGuide();
      _completed
        ..clear()
        ..addAll(
          activities
              .where((activity) => activity.completed)
              .map((activity) => activity.id),
        );
      if (activities.isEmpty) {
        _state = BodyCareViewState.empty;
      } else {
        _selectedArea = loads
            .map((load) => load.area)
            .where(availableAreas.contains)
            .firstOrNull;
        _selectedArea ??= availableAreas.first;
        _state = BodyCareViewState.data;
      }
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        404 => BodyCareViewState.empty,
        401 || 403 => BodyCareViewState.authError,
        503 => BodyCareViewState.serverError,
        _ => BodyCareViewState.error,
      };
    } on Object {
      _state = BodyCareViewState.error;
    }
    notifyListeners();
  }

  void selectArea(String area) {
    if (_selectedArea == area) return;
    _selectedArea = area;
    notifyListeners();
  }

  Future<void> toggleCompleted(String id) async {
    final completed = !_completed.contains(id);
    completed ? _completed.add(id) : _completed.remove(id);
    notifyListeners();
    try {
      await service.setCompleted(id, completed);
    } on Object {
      completed ? _completed.remove(id) : _completed.add(id);
      _state = BodyCareViewState.error;
      notifyListeners();
    }
  }
}

/// 컨디션 입력의 1~5 통증 점수를 집중 부위 카드의 라벨과 진행도로 변환한다.
List<BodyLoad> _conditionLoads(ConditionDraft condition) => [
  _conditionLoad('허리', condition.waistPain),
  _conditionLoad('골반', condition.pelvisPain),
  _conditionLoad('다리', condition.legPain),
  _conditionLoad('손목', condition.wristPain),
];

BodyLoad _conditionLoad(String area, int score) {
  final normalized = score.clamp(1, 5);
  return BodyLoad(
    area,
    const ['괜찮아요', '조금 있어요', '보통이에요', '심해요', '매우 심해요'][normalized - 1],
    normalized / 5,
  );
}
