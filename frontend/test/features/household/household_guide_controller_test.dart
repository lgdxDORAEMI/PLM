import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/household/controllers/household_guide_controller.dart';
import 'package:plm_frontend/features/household/models/household_task.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/controllers/partner_request_controller.dart';

void main() {
  test('선택한 가사를 Partner Request 계약으로 공유한다', () async {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    final controller = HouseholdGuideController();
    addTearDown(controller.dispose);
    addTearDown(PartnerRequestStore.instance.clear);

    await controller.shareSelected();

    expect(controller.shared, isTrue);
    expect(controller.lastRequestId, isNotNull);
    expect(
      PartnerNotificationStore.instance.items.first.requestId,
      controller.lastRequestId,
    );
    expect(
      PartnerRequestStore.instance.request(controller.lastRequestId!).tasks,
      isNotEmpty,
    );
    expect(
      controller.tasks.where((task) => task.selected),
      everyElement(
        predicate<HouseholdTask>(
          (task) => task.status == HouseholdTaskStatus.shared,
        ),
      ),
    );

    final partner = PartnerRequestController(
      requestId: controller.lastRequestId!,
    );
    addTearDown(partner.dispose);
    partner.confirm();
    expect(
      controller.tasks.where((task) => task.selected),
      everyElement(
        predicate<HouseholdTask>(
          (task) => task.status == HouseholdTaskStatus.confirmed,
        ),
      ),
    );
    partner.complete();
    expect(
      controller.tasks.where((task) => task.selected),
      everyElement(
        predicate<HouseholdTask>(
          (task) => task.status == HouseholdTaskStatus.done,
        ),
      ),
    );
  });
}
