import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/sleep/controllers/sleep_guide_controller.dart';
import 'package:plm_frontend/features/sleep/models/sleep_guide.dart';
import 'package:plm_frontend/features/sleep/services/mock_sleep_service.dart';

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
}
