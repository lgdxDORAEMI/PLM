import '../models/sleep_guide.dart';
import 'sleep_service.dart';

class MockSleepService implements SleepService {
  const MockSleepService();

  static const guide = SleepGuideData(
    summaryTitle: '오늘은 충분한 휴식이 필요해요',
    summary: '어젯밤 3회 깼고, 28주차 좌측위 권장 구간이에요',
    recommendedBedtime: '오후 10시 30분',
    environments: [
      SleepEnvironmentSetting(
        type: SleepEnvironmentType.light,
        label: '조명',
        value: '은은하게',
        options: ['아주 어둡게', '은은하게', '독서등'],
        selected: true,
      ),
      SleepEnvironmentSetting(
        type: SleepEnvironmentType.temperature,
        label: '온도',
        value: '24°C',
        options: ['22°C', '23°C', '24°C'],
        selected: true,
      ),
      SleepEnvironmentSetting(
        type: SleepEnvironmentType.humidity,
        label: '습도',
        value: '55%',
        options: ['45%', '50%', '55%', '60%'],
        selected: false,
      ),
      SleepEnvironmentSetting(
        type: SleepEnvironmentType.sound,
        label: '소리',
        value: '잔잔한 빗소리',
        options: ['끄기', '잔잔한 빗소리', '백색 소음'],
        selected: true,
      ),
      SleepEnvironmentSetting(
        type: SleepEnvironmentType.purifier,
        label: '공기청정기',
        value: '조용 모드',
        options: ['끄기', '조용 모드', '자동 모드'],
        selected: true,
      ),
    ],
    tips: [
      '실내 온도는 22~24°C로 맞추기',
      '잠들기 1시간 전부터 조명 낮추기',
      '28주차부터는 왼쪽으로 누워 자기',
      '야간 화장실 이동 시 조명 자동 점등',
    ],
  );

  @override
  Future<SleepGuideData> fetchGuide() async => guide;

  @override
  Future<void> startRoutine(List<SleepEnvironmentSetting> environments) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
