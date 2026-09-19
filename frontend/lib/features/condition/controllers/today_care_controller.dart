import 'package:flutter/foundation.dart';

import '../data/today_care_store.dart';
import '../models/condition_draft.dart';

/// Today Care 선택 상태와 저장을 화면 Widget에서 분리한다.
class TodayCareController extends ChangeNotifier {
  TodayCareController({TodayCareStore? store})
    : _store = store ?? TodayCareStore.instance,
      _draft =
          (store ?? TodayCareStore.instance).today ?? const ConditionDraft();

  final TodayCareStore _store;
  ConditionDraft _draft;
  bool _dirty = false;

  ConditionDraft get draft => _draft;
  bool get isDirty => _dirty;

  void updateNausea(int value) => _update(_draft.copyWith(nausea: value));
  void updateWaistPain(int value) => _update(_draft.copyWith(waistPain: value));
  void updatePelvisPain(int value) =>
      _update(_draft.copyWith(pelvisPain: value));
  void updateLegPain(int value) => _update(_draft.copyWith(legPain: value));
  void updateWristPain(int value) => _update(_draft.copyWith(wristPain: value));
  void updateFatigue(int value) => _update(_draft.copyWith(fatigue: value));
  void updateMood(int value) => _update(_draft.copyWith(mood: value));

  Future<void> save() async {
    _dirty = false;
    notifyListeners();
    try {
      await _store.save(_draft);
    } catch (_) {
      _dirty = true;
      notifyListeners();
      rethrow;
    }
  }

  void _update(ConditionDraft value) {
    _draft = value;
    _dirty = true;
    notifyListeners();
  }
}
