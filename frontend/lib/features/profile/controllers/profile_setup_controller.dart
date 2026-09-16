import 'package:flutter/foundation.dart';

import '../../../routing/route_context.dart';
import '../models/profile_draft.dart';

/// Profile 입력값과 Wizard 이동 규칙을 UI에서 분리해 관리한다.
class ProfileSetupController extends ChangeNotifier {
  ProfileSetupController({required ProfileMode mode})
    : _draft = mode == ProfileMode.edit
          ? ProfileDraft.mockEdit()
          : const ProfileDraft();

  static const int inputStepCount = 6;

  ProfileDraft _draft;
  int _step = 0;
  String? _validationMessage;
  bool _dirty = false;

  ProfileDraft get draft => _draft;
  int get step => _step;
  bool get isSummary => _step == inputStepCount;
  bool get isDirty => _dirty;
  String? get validationMessage => _validationMessage;

  void updateDueDate(DateTime value) =>
      _update(_draft.copyWith(dueDate: value));

  void updateLastPeriodDate(DateTime value) =>
      _update(_draft.copyWith(lastPeriodDate: value));

  void updateAge(String value) => _update(_draft.copyWith(age: value));

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
    _step += 1;
    notifyListeners();
    return true;
  }

  bool moveBack() {
    if (_step == 0) return false;
    _step -= 1;
    _validationMessage = null;
    notifyListeners();
    return true;
  }

  void editStep(int step) {
    assert(step >= 0 && step < inputStepCount);
    _step = step;
    _validationMessage = null;
    notifyListeners();
  }

  void markSaved() {
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
        final age = int.tryParse(_draft.age ?? '');
        final height = double.tryParse(_draft.height ?? '');
        final weight = double.tryParse(_draft.prePregnancyWeight ?? '');
        if (age == null || age < 15 || age > 60) {
          return '나이를 15세에서 60세 사이로 입력해 주세요.';
        }
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
