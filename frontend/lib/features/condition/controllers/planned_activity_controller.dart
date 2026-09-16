import 'package:flutter/foundation.dart';

import '../data/planned_activity_store.dart';

class PlannedActivityController extends ChangeNotifier {
  PlannedActivityController({PlannedActivityStore? store})
    : store = store ?? PlannedActivityStore.instance,
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
  final Set<String> _selected;
  bool _generating = false;

  Set<String> get selected => Set.unmodifiable(_selected);
  bool get generating => _generating;

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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    store.save(_selected);
    _generating = false;
    notifyListeners();
  }
}
