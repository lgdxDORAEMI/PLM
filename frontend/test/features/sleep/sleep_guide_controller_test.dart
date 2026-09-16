import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/sleep/controllers/sleep_guide_controller.dart';
import 'package:plm_frontend/features/sleep/models/sleep_guide.dart';
import 'package:plm_frontend/features/sleep/services/mock_sleep_service.dart';

void main() {
  test('환경 선택과 값 수정 후 mock 루틴을 완료한다', () async {
    final controller = SleepGuideController(service: const MockSleepService());
    await controller.load();

    expect(controller.state, SleepGuideViewState.ready);
    expect(controller.selectedEnvironments, hasLength(4));

    controller.toggleEnvironment(SleepEnvironmentType.humidity);
    controller.updateValue(SleepEnvironmentType.temperature, '23°C');
    expect(controller.selectedEnvironments, hasLength(5));
    expect(
      controller.guide!.environments
          .firstWhere((item) => item.type == SleepEnvironmentType.temperature)
          .value,
      '23°C',
    );

    await controller.startRoutine();
    expect(controller.state, SleepGuideViewState.completed);
  });
}
