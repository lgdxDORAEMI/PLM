import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/household/controllers/household_guide_controller.dart';
import 'package:plm_frontend/features/household/models/household_task.dart';

void main() {
  test('공유와 가전 실행은 로컬 상태만 변경한다', () {
    final controller = HouseholdGuideController();
    controller.runAppliance('vacuum');
    expect(
      controller.tasks.firstWhere((task) => task.id == 'vacuum').status,
      HouseholdTaskStatus.running,
    );
    controller.shareSelected();
    expect(controller.shared, isTrue);
    expect(
      controller.tasks.where((task) => task.selected),
      everyElement(
        predicate<HouseholdTask>(
          (task) => task.status == HouseholdTaskStatus.shared,
        ),
      ),
    );
  });
}
