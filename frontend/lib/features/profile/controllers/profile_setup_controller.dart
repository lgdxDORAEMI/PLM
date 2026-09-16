import 'package:flutter/foundation.dart';

import '../../../routing/route_context.dart';
import '../data/profile_store.dart';
import '../models/profile_draft.dart';

/// Profile 입력값과 Wizard 이동 규칙을 UI에서 분리해 관리한다.
class ProfileSetupController extends ChangeNotifier {
  ProfileSetupController({required ProfileMode mode})
    : _draft = mode == ProfileMode.edit
          ? ProfileStore.instance.profile ?? ProfileDraft.mockEdit()
          : const ProfileDraft();

  static const int inputStepCount = 6;

  ProfileDraft _draft;
  int _step = 0;
  String? _validationMessage;
  bool _dirty = false;
  bool _editingFromSummary = false;

  ProfileDraft get draft => _draft;
  int get step => _step;
  bool get isSummary => _step == inputStepCount;
  bool get isDirty => _dirty;
  String? get validationMessage => _validationMessage;
  bool get editingFromSummary => _editingFromSummary;

  void updateDueDate(DateTime value) =>
      _update(_draft.copyWith(dueDate: value, clearLastPeriodDate: true));

  void updateLastPeriodDate(DateTime value) =>
      _update(_draft.copyWith(lastPeriodDate: value, clearDueDate: true));

  void updateHeight(String value) => _update(_draft.copyWith(height: value));

  void updateWeight(String value) =>
      _update(_draft.copyWith(prePregnancyWeight: value));

  void updateFirstPregnancy(bool value) =>
      _update(_draft.copyWith(isFirstPregnancy: value));

  void updateMultiplePregnancy(bool value) =>
      _update(_draft.copyWith(isMultiplePregnancy: value));

  void toggleAllergy(String value) {
    final next = {..._draft.allergies};
    if (value == '없어요') {
      next
        ..clear()
        ..add(value);
    } else {
      next.remove('없어요');
      next.contains(value) ? next.remove(value) : next.add(value);
    }
    _update(_draft.copyWith(allergies: next));
  }

  void toggleMedicalCondition(String value) {
    final next = {..._draft.medicalConditions};
    next.contains(value) ? next.remove(value) : next.add(value);
    _update(_draft.copyWith(medicalConditions: next));
  }

  void updateMedicalNote(String value) =>
      _update(_draft.copyWith(medicalNote: value));

  /// 현재 단계가 유효할 때만 다음 입력 또는 Summary로 이동한다.
  bool continueToNextStep() {
    final message = _validateCurrentStep();
    if (message != null) {
      _validationMessage = message;
      notifyListeners();
      return false;
    }
    _validationMessage = null;
    if (_editingFromSummary) {
      _step = inputStepCount;
      _editingFromSummary = false;
    } else {
      _step += 1;
    }
    notifyListeners();
    return true;
  }

  bool moveBack() {
    if (_step == 0) return false;
    if (_editingFromSummary) {
      _step = inputStepCount;
      _editingFromSummary = false;
      _validationMessage = null;
      notifyListeners();
      return true;
    }
    _step -= 1;
    _validationMessage = null;
    notifyListeners();
    return true;
  }

  void editStep(int step) {
    assert(step >= 0 && step < inputStepCount);
    _step = step;
    _editingFromSummary = true;
    _validationMessage = null;
    notifyListeners();
  }

  void markSaved() {
    ProfileStore.instance.save(_draft);
    _dirty = false;
    notifyListeners();
  }

  void _update(ProfileDraft value) {
    _draft = value;
    _dirty = true;
    _validationMessage = null;
    notifyListeners();
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_draft.dueDate == null && _draft.lastPeriodDate == null) {
          return '출산예정일 또는 마지막 생리 시작일을 입력해 주세요.';
        }
      case 1:
        final height = double.tryParse(_draft.height ?? '');
        final weight = double.tryParse(_draft.prePregnancyWeight ?? '');
        if (height == null || height < 100 || height > 220) {
          return '키를 100cm에서 220cm 사이로 입력해 주세요.';
        }
        if (weight == null || weight < 30 || weight > 250) {
          return '몸무게를 30kg에서 250kg 사이로 입력해 주세요.';
        }
      case 2:
        if (_draft.isFirstPregnancy == null) {
          return '초산 또는 경산 여부를 선택해 주세요.';
        }
      case 3:
        if (_draft.isMultiplePregnancy == null) {
          return '단태 또는 다태 여부를 선택해 주세요.';
        }
      case 4:
      case 5:
        return null;
    }
    return null;
  }
}
