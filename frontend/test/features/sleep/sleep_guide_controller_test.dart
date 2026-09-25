import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/sleep/controllers/sleep_guide_controller.dart';
import 'package:plm_frontend/features/sleep/models/sleep_guide.dart';
import 'package:plm_frontend/features/sleep/services/mock_sleep_service.dart';
import 'package:plm_frontend/features/sleep/services/sleep_service.dart';

class _FakeSleepService implements SleepService {
  _FakeSleepService({this.deviceId, this.controlOk = true, this.itemId});

  final String? deviceId;
  final bool controlOk;
  final String? itemId;
  String? lastPower;
  String? lastWindStrength;
  final Map<String, bool> completed = {};

  @override
  Future<SleepGuideData> fetchGuide() async => itemId == null
      ? MockSleepService.guide
      : SleepGuideData(
          itemId: itemId,
          summaryTitle: MockSleepService.guide.summaryTitle,
          summary: MockSleepService.guide.summary,
          recommendedBedtime: MockSleepService.guide.recommendedBedtime,
          environments: MockSleepService.guide.environments,
          tips: MockSleepService.guide.tips,
        );

  @override
  Future<void> updateEnvironment(String itemId, Map<String, dynamic> values) async {}

  @override
  Future<void> setCompleted(String itemId, bool completed) async {
    this.completed[itemId] = completed;
  }

  @override
  Future<String?> findAirPurifierDeviceId() async => deviceId;

  @override
  Future<bool> controlAirPurifier(
    String deviceId, {
    required String power,
    String? windStrength,
  }) async {
    lastPower = power;
    lastWindStrength = windStrength;
    return controlOk;
  }
}

void main() {
  test('환경 추천값을 local 상태에서 수정한다', () async {
    final controller = SleepGuideController(service: const MockSleepService());
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.state, SleepGuideViewState.ready);

    controller.updateValue(SleepEnvironmentType.temperature, '23°C');
    expect(
      controller.guide!.environments
          .firstWhere((item) => item.type == SleepEnvironmentType.temperature)
          .value,
      '23°C',
    );
    expect(controller.state, SleepGuideViewState.ready);
  });

  test('공기청정기가 연결되면 조용 모드는 전원 on + wind_strength low를 보낸다', () async {
    final service = _FakeSleepService(deviceId: 'purifier-1');
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.airPurifierConnected, isTrue);
    final ok = await controller.runAirPurifier('조용 모드');

    expect(ok, isTrue);
    expect(service.lastPower, 'on');
    expect(service.lastWindStrength, 'low');
    expect(
      controller.guide!.environments
          .firstWhere((item) => item.type == SleepEnvironmentType.purifier)
          .value,
      '조용 모드',
    );
  });

  test('끄기는 전원 off만 보내고 wind_strength는 보내지 않는다', () async {
    final service = _FakeSleepService(deviceId: 'purifier-1');
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.runAirPurifier('끄기');

    expect(service.lastPower, 'off');
    expect(service.lastWindStrength, isNull);
  });

  test('공기청정기 미연결 시 제어를 시도하지 않고 false를 돌려준다', () async {
    final service = _FakeSleepService();
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.airPurifierConnected, isFalse);
    final ok = await controller.runAirPurifier('자동');

    expect(ok, isFalse);
    expect(service.lastPower, isNull);
  });

  test('수면 환경 전체 실행 시 홈 루틴 진행도용 실행 상태를 완료로 갱신한다', () async {
    final service = _FakeSleepService(itemId: 'sleep-item-1');
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.markCompleted();

    expect(service.completed['sleep-item-1'], isTrue);
  });

  test('실기기 제어 실패 시 표시값을 바꾸지 않는다', () async {
    final service = _FakeSleepService(deviceId: 'purifier-1', controlOk: false);
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);
    await controller.load();
    final before = controller.guide!.environments
        .firstWhere((item) => item.type == SleepEnvironmentType.purifier)
        .value;

    final ok = await controller.runAirPurifier('강풍');

    expect(ok, isFalse);
    expect(
      controller.guide!.environments
          .firstWhere((item) => item.type == SleepEnvironmentType.purifier)
          .value,
      before,
    );
  });
}
