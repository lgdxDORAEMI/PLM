import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/health/controllers/body_care_controller.dart';
import 'package:plm_frontend/features/health/services/mock_health_guide_service.dart';

void main() {
  test('활동 완료 상태를 토글한다', () {
    final controller = BodyCareController(
      service: const MockHealthGuideService(),
    );
    controller.toggleCompleted('pelvis');
    expect(controller.isCompleted('pelvis'), isTrue);
    controller.toggleCompleted('pelvis');
    expect(controller.isCompleted('pelvis'), isFalse);

    controller.selectArea('골반');
    expect(controller.selectedArea, '골반');
  });
}
