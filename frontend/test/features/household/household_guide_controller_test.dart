import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/household/controllers/household_guide_controller.dart';
import 'package:plm_frontend/features/household/models/household_task.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/controllers/partner_request_controller.dart';
import 'package:plm_frontend/features/household/services/mock_household_request_service.dart';

void main() {
  test('선택한 가사를 Partner Request 계약으로 공유한다', () async {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    final controller = HouseholdGuideController();
    addTearDown(controller.dispose);
    addTearDown(PartnerRequestStore.instance.clear);

    expect(
      controller.directListTasks.map((task) => task.id),
      contains('heavy-items'),
    );
    controller.toggleSelection('clear-table');
    await controller.shareSelected();

    expect(controller.shared, isTrue);
    expect(controller.lastRequestId, isNotNull);
    expect(
      PartnerNotificationStore.instance.items.first.requestId,
      controller.lastRequestId,
    );
    final sharedTasks = PartnerRequestStore.instance
        .request(controller.lastRequestId!)
        .tasks;
    expect(sharedTasks, hasLength(2));
    expect(
      sharedTasks.map((task) => task.title),
      containsAll(['식탁 위 정리 — 서서 5분', '장보기 · 무거운 것 옮기기']),
    );
    expect(
      controller.directListTasks.map((task) => task.id),
      isNot(containsAll(['clear-table', 'heavy-items'])),
    );
    expect(
      controller.directListTasks.map((task) => task.id),
      contains('water-plants'),
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
      service: MockHouseholdRequestService(),
    );
    addTearDown(partner.dispose);
    await partner.load();
    final firstTask = partner.request!.tasks.first;
    await partner.confirmTask(firstTask.id);
    expect(
      controller.tasks.where((task) => task.selected),
      everyElement(
        predicate<HouseholdTask>(
          (task) => task.status == HouseholdTaskStatus.confirmed,
        ),
      ),
    );

    await partner.completeTask(firstTask.id);
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
