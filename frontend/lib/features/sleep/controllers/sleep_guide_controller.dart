import 'package:flutter/foundation.dart';

import '../models/sleep_guide.dart';
import '../services/sleep_service.dart';

enum SleepGuideViewState { loading, ready, running, completed, error }

class SleepGuideController extends ChangeNotifier {
  SleepGuideController({required this.service});

  final SleepService service;
  SleepGuideViewState _state = SleepGuideViewState.loading;
  SleepGuideData? _guide;

  SleepGuideViewState get state => _state;
  SleepGuideData? get guide => _guide;
  List<SleepEnvironmentSetting> get selectedEnvironments =>
      _guide?.environments.where((item) => item.selected).toList() ?? const [];

  /// 데이터 공급자가 바뀌어도 화면은 동일한 상태 전이를 사용한다.
  Future<void> load() async {
    _state = SleepGuideViewState.loading;
    notifyListeners();
    try {
      _guide = await service.fetchGuide();
      _state = SleepGuideViewState.ready;
    } on Object {
      _state = SleepGuideViewState.error;
    }
    notifyListeners();
  }

  void toggleEnvironment(SleepEnvironmentType type) {
    _replace(type, (item) => item.copyWith(selected: !item.selected));
  }

  void updateValue(SleepEnvironmentType type, String value) {
    _replace(type, (item) => item.copyWith(value: value));
  }

  /// 현재 단계에서는 실제 가전 대신 선택값을 Mock Service에만 전달한다.
  Future<void> startRoutine() async {
    if (selectedEnvironments.isEmpty || _state == SleepGuideViewState.running) {
      return;
    }
    _state = SleepGuideViewState.running;
    notifyListeners();
    try {
      await service.startRoutine(selectedEnvironments);
      _state = SleepGuideViewState.completed;
    } on Object {
      _state = SleepGuideViewState.error;
    }
    notifyListeners();
  }

  void _replace(
    SleepEnvironmentType type,
    SleepEnvironmentSetting Function(SleepEnvironmentSetting) update,
  ) {
    final current = _guide;
    if (current == null) return;
    _guide = SleepGuideData(
      summaryTitle: current.summaryTitle,
      summary: current.summary,
      recommendedBedtime: current.recommendedBedtime,
      environments: [
        for (final item in current.environments)
          if (item.type == type) update(item) else item,
      ],
      tips: current.tips,
    );
    if (_state == SleepGuideViewState.completed) {
      _state = SleepGuideViewState.ready;
    }
    notifyListeners();
  }
}
