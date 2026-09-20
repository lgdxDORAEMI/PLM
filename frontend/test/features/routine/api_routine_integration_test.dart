import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/condition/data/api_condition_repository.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/condition/services/api_planned_activity_service.dart';
import 'package:plm_frontend/features/routine/services/api_routine_service.dart';

void main() {
  test('컨디션, 예정 활동, 루틴 생성 순서와 서버 폴백 상태를 유지한다', () async {
    final paths = <String>[];
    final day = DateTime.now();
    final date =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final client = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/v1/routine/today') {
          return http.Response(
            jsonEncode({
              'date': date,
              'source': 'fallback_template',
              'response': {
                'meal': [
                  {'item_key': 'meal:1', 'title': '식사', 'payload': {}},
                ],
                'household': [],
                'health': [],
                'sleep': [],
              },
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await ApiConditionRepository(client).saveToday(day, const ConditionDraft());
    await ApiPlannedActivityService(
      client: client,
    ).saveAndGenerate(day, ['청소']);
    final plan = await ApiRoutineService(client: client).fetchToday();

    expect(paths, [
      'PUT /api/v1/care/conditions/$date',
      'PUT /api/v1/care/conditions/$date/activities',
      'POST /api/v1/routine/today',
    ]);
    expect(plan.isBackendFallback, isTrue);
    expect(plan.items.single.title, '식사');
  });
}
