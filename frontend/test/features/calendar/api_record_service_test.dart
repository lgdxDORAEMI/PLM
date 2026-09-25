import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/report/services/api_record_service.dart';

void main() {
  test('컨디션 요약에 저장된 7종 점수를 모두 포함한다', () async {
    final service = _serviceWithCondition({
      'nausea': 1,
      'waist_pain': 1,
      'pelvis_pain': 1,
      'leg_pain': 4,
      'wrist_pain': 5,
      'fatigue': 1,
      'mood': 3,
    });

    final record = await service.fetchCalendarRecord(DateTime(2026, 9, 13));

    expect(
      record?.conditionSummary,
      '입덧 1점 · 허리 1점 · 골반 1점 · 다리 4점 · 손목 5점 · 피로 1점 · 기분 3점',
    );
  });

  test('높은 항목이 없어도 저장된 컨디션 점수를 생략하지 않는다', () async {
    final service = _serviceWithCondition({
      'nausea': 2,
      'waist_pain': 2,
      'pelvis_pain': 2,
      'leg_pain': 2,
      'wrist_pain': 2,
      'fatigue': 2,
      'mood': 3,
    });

    final record = await service.fetchCalendarRecord(DateTime(2026, 9, 13));

    expect(
      record?.conditionSummary,
      '입덧 2점 · 허리 2점 · 골반 2점 · 다리 2점 · 손목 2점 · 피로 2점 · 기분 3점',
    );
  });

  test('Daily 리포트 조회는 기존 리포트와 컨디션 API 계약을 유지한다', () async {
    final requests = <String>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'GET' &&
            request.url.path.contains('/daily-reports/')) {
          return http.Response('', 404);
        }
        if (request.method == 'GET' &&
            request.url.path.contains('/conditions/')) {
          return http.Response(jsonEncode(_normalCondition), 200);
        }
        return http.Response(jsonEncode(_emptyReport), 200);
      }),
    );

    await ApiRecordService(client: client).fetchRecord(DateTime(2026, 9, 13));

    expect(requests, [
      'GET /api/v1/care/daily-reports/2026-09-13',
      'POST /api/v1/care/daily-reports/2026-09-13/preview',
      'GET /api/v1/care/conditions/2026-09-13',
    ]);
  });

  test('통합 API가 아직 배포되지 않았으면 기존 상세 API로 폴백한다', () async {
    final requests = <String>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.contains('/calendar/days/')) {
          return http.Response('', 404);
        }
        if (request.url.path.contains('/conditions/')) {
          return http.Response(jsonEncode(_normalCondition), 200);
        }
        return http.Response(jsonEncode(_emptyReport), 200);
      }),
    );

    final record = await ApiRecordService(
      client: client,
    ).fetchCalendarRecord(DateTime(2026, 9, 13));

    expect(record, isNotNull);
    expect(requests, [
      'GET /api/v1/care/calendar/days/2026-09-13',
      'GET /api/v1/care/daily-reports/2026-09-13',
      'GET /api/v1/care/conditions/2026-09-13',
    ]);
  });

  test('기록이 없는 날은 폴백하지 않고 바로 비어 있다고 알린다', () async {
    // 09-25: 기록 없는 날을 404로 주면 구버전 백엔드와 구분되지 않아 폴백 3회가 더 나갔다.
    final requests = <String>[];
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({'condition': null, 'report': null}),
          200,
        );
      }),
    );

    final record = await ApiRecordService(
      client: client,
    ).fetchCalendarRecord(DateTime(2026, 9, 13));

    expect(record, isNull);
    expect(requests, ['GET /api/v1/care/calendar/days/2026-09-13']);
  });
}

ApiRecordService _serviceWithCondition(Map<String, dynamic> condition) {
  final client = ApiClient(
    baseUrl: 'https://example.test',
    httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/care/calendar/days/2026-09-13');
      return http.Response(
        jsonEncode({'condition': condition, 'report': _emptyReport}),
        200,
      );
    }),
  );
  return ApiRecordService(client: client);
}

const _normalCondition = {
  'nausea': 2,
  'waist_pain': 2,
  'pelvis_pain': 2,
  'leg_pain': 2,
  'wrist_pain': 2,
  'fatigue': 2,
  'mood': 3,
};

const _emptyReport = {
  'completed_routines': 0,
  'appliance_executions': 0,
  'routines': <Object>[],
  'family': {'requested': 0, 'confirmed': 0, 'completed': 0},
  'motion_cautions': <Object>[],
  'motion_summaries': <Object>[],
};
