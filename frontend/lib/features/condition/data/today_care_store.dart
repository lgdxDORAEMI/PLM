import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../models/condition_draft.dart';
import '../../routine/services/api_routine_service.dart';
import 'api_condition_repository.dart';
import 'condition_repository.dart';
import 'mock_condition_repository.dart';

/// Shares today's condition between the entry form and home screen.
class TodayCareStore extends ChangeNotifier {
  TodayCareStore._({ConditionRepository? repository})
    : _repository =
          repository ??
          (AppConfig.hasSupabaseConfig
              ? ApiConditionRepository(ApiClient())
              : MockConditionRepository());

  static final TodayCareStore instance = TodayCareStore._();

  @visibleForTesting
  factory TodayCareStore.withRepository(ConditionRepository repository) =>
      TodayCareStore._(repository: repository);

  final ConditionRepository _repository;
  ConditionDraft? _today;
  DateTime? _loadedDate;

  ConditionDraft? get today => _today;
  bool get hasTodayCare => _today != null;

  /// Restores today's record after a page reload without repeating requests.
  Future<void> loadToday() async {
    final date = DateTime.now();
    if (_loadedDate != null &&
        _loadedDate!.year == date.year &&
        _loadedDate!.month == date.month &&
        _loadedDate!.day == date.day) {
      return;
    }
    final value = await _repository.fetchToday(date);
    _loadedDate = date;
    _today = value;
    notifyListeners();
  }

  /// Rolls back the visible value if the API rejects a save.
  Future<void> save(ConditionDraft value) async {
    final previous = _today;
    _today = value;
    notifyListeners();
    try {
      await _repository.saveToday(DateTime.now(), value);
      _loadedDate = DateTime.now();
      if (!_sameCondition(previous, value)) {
        ApiRoutineService.invalidateCache();
      }
    } catch (_) {
      _today = previous;
      notifyListeners();
      rethrow;
    }
  }

  void finishDay() {
    _today = null;
    _loadedDate = DateTime.now();
    notifyListeners();
  }

  void clear() {
    _today = null;
    _loadedDate = null;
    notifyListeners();
  }

  bool _sameCondition(ConditionDraft? left, ConditionDraft right) =>
      left != null &&
      left.nausea == right.nausea &&
      left.waistPain == right.waistPain &&
      left.pelvisPain == right.pelvisPain &&
      left.legPain == right.legPain &&
      left.wristPain == right.wristPain &&
      left.fatigue == right.fatigue &&
      left.mood == right.mood;
}
