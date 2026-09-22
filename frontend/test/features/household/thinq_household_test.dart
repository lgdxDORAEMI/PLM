import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/household/models/household_task.dart';
import 'package:plm_frontend/features/household/services/api_household_request_service.dart';
import 'package:plm_frontend/features/household/widgets/household_task_card.dart';

void main() {
  test('가사 응답의 가전 목록과 기존 직접/가족 항목을 파싱한다', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/household/today');
        return http.Response(
          jsonEncode({
            'appliance_connection_status': 'connected',
            'items': [
              {
                'item_id': 'laundry',
                'title': '빨래',
                'status': 'scheduled',
                'payload': {
                  'owner': 'appliance',
                  'appliances': [
                    {'name': '세탁기', 'device_type': 'washer', 'device_id': 'w'},
                    {'name': '건조기', 'device_type': 'dryer', 'device_id': 'd'},
                  ],
                },
              },
              {
                'item_id': 'self',
                'title': '화분 관리',
                'payload': {'owner': 'self'},
              },
              {
                'item_id': 'partner',
                'title': '장보기',
                'payload': {'owner': 'partner'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = ApiHouseholdRequestService(client: client);
    final tasks = await service.fetchGuide();
    expect(service.applianceConnectionStatus, 'connected');
    expect(tasks.map((task) => task.owner), [
      HouseholdTaskOwner.appliance,
      HouseholdTaskOwner.self,
      HouseholdTaskOwner.partner,
    ]);
    expect(tasks.first.applianceNames, ['세탁기', '건조기']);
    expect(tasks.last.selected, isTrue);
  });

  test('가전 0개인 정상 응답은 빈 목록을 유지한다', () async {
    final service = ApiHouseholdRequestService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'appliance_connection_status': 'connected',
              'items': [],
            }),
            200,
          ),
        ),
      ),
    );
    expect(await service.fetchGuide(), isEmpty);
  });

  testWidgets('실제 보유 가전 이름을 카드에 표시하고 임의 시간은 표시하지 않는다', (tester) async {
    const task = HouseholdTask(
      id: 'laundry',
      title: '빨래',
      description: '약 45분',
      owner: HouseholdTaskOwner.appliance,
      applianceNames: ['세탁기', '건조기'],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HouseholdTaskCard(task: task)),
      ),
    );
    expect(find.text('세탁기 · 건조기'), findsOneWidget);
    expect(find.text('약 45분'), findsNothing);
  });
}
