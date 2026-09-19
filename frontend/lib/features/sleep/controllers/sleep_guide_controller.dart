import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/sleep_guide.dart';
import '../services/sleep_service.dart';

enum SleepGuideViewState {
  loading,
  ready,
  empty,
  authError,
  domainError,
  serverError,
  error,
}

class SleepGuideController extends ChangeNotifier {
  SleepGuideController({required this.service});

  final SleepService service;
  SleepGuideViewState _state = SleepGuideViewState.loading;
  SleepGuideData? _guide;

  SleepGuideViewState get state => _state;
  SleepGuideData? get guide => _guide;

  /// 데이터 공급자가 바뀌어도 화면은 동일한 상태 전이를 사용한다.
  Future<void> load() async {
    _state = SleepGuideViewState.loading;
    notifyListeners();
    try {
      _guide = await service.fetchGuide();
      _state = _guide!.environments.isEmpty && _guide!.tips.isEmpty
          ? SleepGuideViewState.empty
          : SleepGuideViewState.ready;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => SleepGuideViewState.authError,
        409 || 422 => SleepGuideViewState.domainError,
        503 => SleepGuideViewState.serverError,
        _ => SleepGuideViewState.error,
      };
    } on Object {
      _state = SleepGuideViewState.error;
    }
    notifyListeners();
  }

  void updateValue(SleepEnvironmentType type, String value) {
    _replace(type, (item) => item.copyWith(value: value));
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
    notifyListeners();
  }
}
