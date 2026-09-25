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
  final Map<String, HealthExecutionStatus> _statuses = {};
  final Set<String> _updating = {};
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
  Set<String> get focusAreas =>
      loads.isEmpty ? const {'전신'} : loads.map((load) => load.area).toSet();
  List<BodyLoad> get focusLoads =>
      loads.isEmpty ? const [BodyLoad('전신', '추천 활동', 1)] : loads;
  List<String> get otherAreas => availableAreas
      .where((area) => !focusAreas.contains(area))
      .toList(growable: false);
  String get selectedArea => _selectedArea ?? '';
  bool isCompleted(String id) =>
      _statuses[id] == HealthExecutionStatus.completed;
  bool isSkipped(String id) => _statuses[id] == HealthExecutionStatus.skipped;
  bool isDone(String id) => isCompleted(id) || isSkipped(id);
  bool isUpdating(String id) => _updating.contains(id);
  bool isFocusActivity(BodyCareActivity activity) =>
      activity.isFocus ?? focusAreas.contains(activity.area);
  List<BodyCareActivity> get selectedActivities => activities
      .where((activity) => activity.area == selectedArea)
      .toList(growable: false);

  Future<void> load() async {
    _state = BodyCareViewState.loading;
    notifyListeners();
    try {
      await conditionStore.loadToday();
      _guide = await service.fetchGuide();
      _statuses
        ..clear()
        ..addEntries(
          activities.map(
            (activity) => MapEntry(
              activity.id,
              activity.completed
                  ? HealthExecutionStatus.completed
                  : activity.skipped
                  ? HealthExecutionStatus.skipped
                  : HealthExecutionStatus.scheduled,
            ),
          ),
        );
      if (activities.isEmpty) {
        _state = BodyCareViewState.empty;
      } else {
        final focusLoads = loads;
        _selectedArea = focusLoads.isEmpty && availableAreas.contains('전신')
            ? '전신'
            : focusLoads
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

  /// 활동 완료는 취소할 수 없는 최종 상태로 한 번만 저장한다.
  Future<void> complete(String id) async {
    if (isDone(id) || isUpdating(id)) return;
    await _setStatus(id, HealthExecutionStatus.completed);
  }

  /// 오늘 안하기도 진행도상 완료인 최종 상태이며 다시 예정 상태로 되돌리지 않는다.
  Future<void> skipToday(String id) async {
    if (isDone(id) || isUpdating(id)) return;
    await _setStatus(id, HealthExecutionStatus.skipped);
  }

  Future<void> _setStatus(String id, HealthExecutionStatus next) async {
    final previous = _statuses[id] ?? HealthExecutionStatus.scheduled;
    _updating.add(id);
    _statuses[id] = next;
    notifyListeners();
    try {
      await service.setStatus(id, next);
    } on Object {
      _statuses[id] = previous;
      _state = BodyCareViewState.error;
    } finally {
      _updating.remove(id);
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
