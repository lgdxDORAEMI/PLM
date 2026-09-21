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
    // 카드(항목)별로 독립된 상태를 가지므로 확인한 항목만 바뀌고, 같은 요청의
    // 나머지 항목은 그대로 shared 상태여야 한다.
    final selectedTasks = controller.tasks
        .where((task) => task.selected)
        .toList(growable: false);
    expect(
      selectedTasks.firstWhere((task) => task.title == firstTask.title).status,
      HouseholdTaskStatus.confirmed,
    );
    expect(
      selectedTasks.firstWhere((task) => task.title != firstTask.title).status,
      HouseholdTaskStatus.shared,
    );

    await partner.completeTask(firstTask.id);
    final selectedAfterComplete = controller.tasks
        .where((task) => task.selected)
        .toList(growable: false);
    expect(
      selectedAfterComplete
          .firstWhere((task) => task.title == firstTask.title)
          .status,
      HouseholdTaskStatus.done,
    );
    expect(
      selectedAfterComplete
          .firstWhere((task) => task.title != firstTask.title)
          .status,
      HouseholdTaskStatus.shared,
    );
  });
}
