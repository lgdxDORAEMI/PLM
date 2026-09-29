import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/sleep/controllers/sleep_guide_controller.dart';
import 'package:plm_frontend/features/sleep/services/api_sleep_service.dart';
import 'package:plm_frontend/features/sleep/models/sleep_guide.dart';
import 'package:plm_frontend/features/sleep/services/mock_sleep_service.dart';
import 'package:plm_frontend/features/sleep/services/sleep_service.dart';

class _FakeSleepService implements SleepService {
  _FakeSleepService({
    this.deviceId,
    this.controlOk = true,
    this.itemId,
    this.connectionStatus,
  });

  final String? deviceId;
  final bool controlOk;
  final String? itemId;
  final String? connectionStatus;
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
  Future<void> updateEnvironment(
    String itemId,
    Map<String, dynamic> values,
  ) async {}

  @override
  Future<void> setCompleted(String itemId, bool completed) async {
    this.completed[itemId] = completed;
  }

  @override
  Future<String?> findAirPurifierDeviceId() async {
    if (connectionStatus case final status?) {
      throw ThinQConnectionException(status);
    }
    return deviceId;
  }

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
  test('수면 환경 실행 완료는 가전 실행으로 기록한다', () async {
    // 09-27: 완료자가 wife로만 저장돼 리포트의 가전 실행 수가 늘 0이었다.
    http.Request? put;
    final service = ApiSleepService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          put = request;
          return http.Response('{}', 200);
        }),
      ),
    );

    await service.setCompleted('sleep-item', true);

    expect(put?.url.path, '/api/v1/care/routine-items/sleep-item/execution');
    expect(jsonDecode(put!.body), {
      'status': 'completed',
      'by_appliance': true,
    });
  });

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

  test('ThinQ 인증 실패를 미등록 기기와 구분한다', () async {
    final service = _FakeSleepService(connectionStatus: 'auth_error');
    final controller = SleepGuideController(service: service);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.airPurifierConnected, isFalse);
    expect(controller.airPurifierConnectionStatus, 'auth_error');
    expect(controller.state, SleepGuideViewState.ready);
  });

  test('기기 조회 API의 연결 실패 상태를 예외로 전달한다', () async {
    final service = ApiSleepService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'not_configured', 'devices': []}),
            200,
          ),
        ),
      ),
    );

    expect(
      service.findAirPurifierDeviceId,
      throwsA(
        isA<ThinQConnectionException>().having(
          (error) => error.status,
          'status',
          'not_configured',
        ),
      ),
    );
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
