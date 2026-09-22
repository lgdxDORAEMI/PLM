import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../data/planned_activity_store.dart';
import '../services/api_planned_activity_service.dart';
import '../services/mock_planned_activity_service.dart';
import '../services/planned_activity_service.dart';

class PlannedActivityController extends ChangeNotifier {
  PlannedActivityController({
    PlannedActivityStore? store,
    PlannedActivityService? service,
  }) : store = store ?? PlannedActivityStore.instance,
       service =
           service ??
           (AppConfig.hasSupabaseConfig
               ? ApiPlannedActivityService()
               : const MockPlannedActivityService()),
       _selected = {...(store ?? PlannedActivityStore.instance).activities};

  static const options = [
    '장보기',
    '빨래',
    '청소',
    '설거지',
    '요리',
    '쓰레기 배출',
    '침구 정리',
    '화분 관리',
    '정리 정돈',
  ];

  final PlannedActivityStore store;
  final PlannedActivityService service;
  final Set<String> _selected;
  bool _generating = false;

  Set<String> get selected => Set.unmodifiable(_selected);
  bool get generating => _generating;

  /// Restores activities from the condition record when the page is reopened.
  Future<void> loadActivities() async {
    final values = await service.fetch(DateTime.now());
    if (values.isEmpty && !AppConfig.hasSupabaseConfig) return;
    _selected
      ..clear()
      ..addAll(values);
    store.save(_selected);
    notifyListeners();
  }

  void toggle(String value) {
    _selected.contains(value) ? _selected.remove(value) : _selected.add(value);
    notifyListeners();
  }

  void addCustom(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    _selected.add(normalized);
    notifyListeners();
  }

  /// 실제 AI 호출 전까지 선택값 저장과 생성 대기 상태만 모사한다.
  Future<void> generateRoutine() async {
    if (_generating) return;
    _generating = true;
    notifyListeners();
    try {
      await service.saveAndGenerate(DateTime.now(), _selected.toList());
      store.save(_selected);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  /// The first daily flow saves activities before opening the invitation step.
  Future<void> saveActivities() async {
    if (_generating) return;
    _generating = true;
    notifyListeners();
    try {
      await service.saveActivities(DateTime.now(), _selected.toList());
      store.save(_selected);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }
}
