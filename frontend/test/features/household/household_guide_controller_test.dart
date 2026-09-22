import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/household/controllers/household_guide_controller.dart';
import 'package:plm_frontend/features/household/models/household_task.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/controllers/partner_request_controller.dart';
import 'package:plm_frontend/features/household/services/mock_household_request_service.dart';
import 'package:plm_frontend/features/household/services/api_household_request_service.dart';

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
    expect(controller.shareableTasks.map((task) => task.id), [
      'water-plants',
      'clear-table',
      'heavy-items',
    ]);
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

  test('남은 가사를 다시 공유하고 이전 요청의 완료 상태도 유지한다', () async {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    final controller = HouseholdGuideController();
    addTearDown(controller.dispose);
    addTearDown(PartnerRequestStore.instance.clear);

    expect(await controller.shareSelected(), isTrue);
    final firstRequestId = controller.lastRequestId!;
    expect(controller.remainingShareableCount, 2);
    expect(controller.selectedCount, 0);

    controller.toggleSelection('heavy-items');
    expect(controller.selectedCount, 0);
    controller.toggleSelection('clear-table');
    expect(await controller.shareSelected(), isTrue);
    expect(controller.lastRequestId, isNot(firstRequestId));
    expect(PartnerRequestStore.instance.requests, hasLength(2));
    expect(controller.remainingShareableCount, 1);
    expect(controller.shareableTasks.map((task) => task.id), [
      'water-plants',
      'clear-table',
      'heavy-items',
    ]);

    final partner = PartnerRequestController(
      requestId: firstRequestId,
      service: MockHouseholdRequestService(),
    );
    addTearDown(partner.dispose);
    await partner.load();
    final itemId = partner.request!.tasks.single.id;
    await partner.confirmTask(itemId);
    await partner.completeTask(itemId);
    expect(
      controller.tasks.firstWhere((task) => task.id == 'heavy-items').status,
      HouseholdTaskStatus.done,
    );
    expect(
      controller.tasks.firstWhere((task) => task.id == 'clear-table').status,
      HouseholdTaskStatus.shared,
    );
  });

  test('여러 요청의 기존 확인·완료를 항목 ID로 복원하고 남은 항목을 추가 요청한다', () async {
    final today = DateTime.now();
    final dateKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    Map<String, dynamic>? posted;
    final client = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/household/today') {
          return http.Response(
            jsonEncode({
              'items': [
                for (final id in ['task-a', 'task-b', 'task-c'])
                  {
                    'item_id': id,
                    'title': '같은 이름의 할 일',
                    'status': 'scheduled',
                    'payload': {'owner': 'partner'},
                  },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/family/household-requests' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'request_id': 'request-a',
                'target_date': dateKey,
                'items': [
                  {
                    'item_id': 'item-a',
                    'routine_item_id': 'task-a',
                    'title': '같은 이름의 할 일',
                    'status': 'confirmed',
                  },
                ],
              },
              {
                'request_id': 'request-b',
                'target_date': dateKey,
                'items': [
                  {
                    'item_id': 'item-b',
                    'routine_item_id': 'task-b',
                    'title': '같은 이름의 할 일',
                    'status': 'completed',
                  },
                ],
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/family/household-requests' &&
            request.method == 'POST') {
          posted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'request_id': 'request-c'}), 201);
        }
        return http.Response('Not found', 404);
      }),
    );
    final service = ApiHouseholdRequestService(client: client);
    final controller = HouseholdGuideController(requestService: service);
    addTearDown(controller.dispose);
    addTearDown(service.dispose);

    expect(await service.fetchGuide(), hasLength(3));
    expect(await service.fetchAll(), hasLength(2));
    await controller.loadGuide();
    expect(controller.loadFailed, isFalse);
    expect(controller.tasks.map((task) => task.id), [
      'task-a',
      'task-b',
      'task-c',
    ]);
    expect(controller.tasks[0].status, HouseholdTaskStatus.confirmed);
    expect(controller.tasks[1].status, HouseholdTaskStatus.done);
    expect(controller.tasks[2].status, HouseholdTaskStatus.planned);
    expect(controller.remainingShareableCount, 1);
    expect(controller.selectedCount, 1);

    expect(await controller.shareSelected(), isTrue);
    expect(posted!['items'], [
      {
        'title': '같은 이름의 할 일',
        'helper_info': '선택한 가사 항목을 전달했어요.',
        'routine_item_id': 'task-c',
      },
    ]);
    expect(controller.tasks[0].status, HouseholdTaskStatus.confirmed);
    expect(controller.tasks[1].status, HouseholdTaskStatus.done);
    expect(controller.tasks[2].status, HouseholdTaskStatus.shared);
    expect(controller.remainingShareableCount, 0);
  });
}
