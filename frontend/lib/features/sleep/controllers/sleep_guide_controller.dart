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

/// 팀이 확정한 공기청정기 실제 제어 4종(취침 예약 타이머는 이번 범위에서 제외).
class PurifierCommand {
  const PurifierCommand(this.power, this.windStrength);
  final String power;
  final String? windStrength;
}

const purifierCommands = <String, PurifierCommand>{
  '조용 모드': PurifierCommand('on', 'low'),
  '자동': PurifierCommand('on', 'auto'),
  '강풍': PurifierCommand('on', 'high'),
  '끄기': PurifierCommand('off', null),
};

class SleepGuideController extends ChangeNotifier {
  SleepGuideController({required this.service});

  final SleepService service;
  SleepGuideViewState _state = SleepGuideViewState.loading;
  SleepGuideData? _guide;
  String? _airPurifierDeviceId;

  SleepGuideViewState get state => _state;
  SleepGuideData? get guide => _guide;
  bool get airPurifierConnected => _airPurifierDeviceId != null;

  /// 데이터 공급자가 바뀌어도 화면은 동일한 상태 전이를 사용한다.
  Future<void> load() async {
    _state = SleepGuideViewState.loading;
    notifyListeners();
    try {
      _guide = await service.fetchGuide();
      _state = _guide!.environments.isEmpty && _guide!.tips.isEmpty
          ? SleepGuideViewState.empty
          : SleepGuideViewState.ready;
      if (_state == SleepGuideViewState.ready) {
        try {
          _airPurifierDeviceId = await service.findAirPurifierDeviceId();
        } on Object {
          _airPurifierDeviceId = null;
        }
      }
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        404 => SleepGuideViewState.empty,
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

  /// 팀이 확정한 4개 라벨 중 하나로 실기기를 제어하고, 성공 시에만 표시값도 갱신한다.
  Future<bool> runAirPurifier(String label) async {
    final deviceId = _airPurifierDeviceId;
    final command = purifierCommands[label];
    if (deviceId == null || command == null) return false;
    final ok = await service.controlAirPurifier(
      deviceId,
      power: command.power,
      windStrength: command.windStrength,
    );
    if (ok) await updateValue(SleepEnvironmentType.purifier, label);
    return ok;
  }

  Future<void> updateValue(SleepEnvironmentType type, String value) async {
    final itemId = _guide?.itemId;
    if (itemId != null) {
      try {
        final key = switch (type) {
          SleepEnvironmentType.light => 'lighting',
          SleepEnvironmentType.temperature => 'temperature',
          SleepEnvironmentType.humidity => 'humidity',
          SleepEnvironmentType.sound => 'sound',
          SleepEnvironmentType.purifier => 'air_purifier',
        };
        final number = num.tryParse(
          RegExp(r'\d+(?:\.\d+)?').firstMatch(value)?.group(0) ?? '',
        );
        await service.updateEnvironment(itemId, {
          key:
              type == SleepEnvironmentType.temperature ||
                  type == SleepEnvironmentType.humidity
              ? number ?? value
              : value,
        });
      } on Object {
        _state = SleepGuideViewState.error;
        notifyListeners();
        return;
      }
    }
    _replace(type, (item) => item.copyWith(value: value));
  }

  void _replace(
    SleepEnvironmentType type,
    SleepEnvironmentSetting Function(SleepEnvironmentSetting) update,
  ) {
    final current = _guide;
    if (current == null) return;
    _guide = SleepGuideData(
      itemId: current.itemId,
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
