import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/health/models/body_care_guide.dart';
import 'package:plm_frontend/features/invitation/services/api_partner_link_service.dart';
import 'package:plm_frontend/features/movement/services/api_movement_dashboard_service.dart';
import 'package:plm_frontend/features/partner/models/partner_notification.dart';
import 'package:plm_frontend/features/partner/models/partner_request.dart';

void main() {
  test('가사 요청과 알림 API 응답을 화면 모델로 파싱한다', () {
    final request = PartnerRequestData.fromJson({
      'request_id': 'request-1',
      'target_date': '2026-09-20',
      'requester_display_name': '희선',
      'reason': '허리 부담',
      'items': [
        {
          'item_id': 'item-1',
          'title': '무거운 물건 옮기기',
          'helper_info': '천천히 옮겨 주세요',
          'status': 'confirmed',
        },
      ],
    });
    final notification = PartnerNotificationItem.fromJson({
      'notification_id': 'notification-1',
      'type': 'household_request',
      'title': '가사 요청',
      'body': '새 요청이 도착했어요',
      'reference_id': 'request-1',
      'created_at': '2026-09-20T00:00:00Z',
      'read_at': null,
    });

    expect(request.tasks.single.status, PartnerRequestStatus.confirmed);
    expect(request.tasks.single.description, '천천히 옮겨 주세요');
    expect(notification.requestId, 'request-1');
    expect(notification.read, isFalse);
  });

  test('건강 가이드 payload를 부위와 활동 모델로 파싱한다', () {
    final guide = BodyCareGuideData.fromJson({
      'items': [
        {
          'item_key': 'health:waist',
          'title': '허리 이완',
          'description': '가볍게 움직여요',
          'payload': {
            'bodyArea': '허리',
            'guide': '통증 없는 범위에서 움직여요.',
            'loads': [
              {'area': '허리', 'label': '부담 높음', 'value': 0.8},
            ],
          },
        },
      ],
    });

    expect(guide.activities.single.id, 'health:waist');
    expect(guide.activities.single.area, '허리');
    expect(guide.loads.single.value, 0.8);
  });

  test('Movement 이벤트·일일 집계·동의 상태를 함께 파싱한다', () async {
    final service = ApiMovementDashboardService(
      client: _client((request) async {
        if (request.url.path.endsWith('/events')) {
          return _jsonResponse([
            {
              'event_id': 'event-1',
              'posture_type': 'bending',
              'burden_label': 'Repeated Load',
              'trigger_reason': 'repetition_threshold',
              'started_at': '2026-09-20T01:10:00Z',
              'ended_at': '2026-09-20T01:11:00Z',
              'duration_sec': 60,
            },
          ]);
        }
        if (request.url.path.endsWith('/report/daily')) {
          return _jsonResponse({
            'cumulative_forward_bend_sec': 180,
            'bending_burden_event_count': 2,
            'narratives': ['반복 부담이 감지됐어요.'],
          });
        }
        return _jsonResponse({
          'consent_granted': true,
          'collection_enabled': true,
          'updated_at': '2026-09-20T00:00:00Z',
        });
      }),
    );

    final data = await service.fetch();

    expect(data.alerts.single.id, 'event-1');
    expect(data.forwardBendSeconds, 180);
    expect(data.burdenEventCount, 2);
    expect(data.consentGranted, isTrue);
    expect(data.collectionEnabled, isTrue);
  });

  test('배우자 연결 상태와 표시명을 파싱한다', () async {
    final service = ApiPartnerLinkService(
      client: _client(
        (_) async =>
            _jsonResponse({'status': 'linked', 'partner_display_name': '연준'}),
      ),
    );

    final link = await service.fetch();

    expect(link.linked, isTrue);
    expect(link.partnerDisplayName, '연준');
  });
}

ApiClient _client(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      httpClient: MockClient(handler),
      baseUrl: 'http://localhost:8000',
    );

http.Response _jsonResponse(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
