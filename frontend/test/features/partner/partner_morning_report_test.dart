import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/partner/controllers/partner_morning_report_controller.dart';
import 'package:plm_frontend/features/partner/models/partner_morning_report.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/features/partner/services/api_partner_morning_report_service.dart';
import 'package:plm_frontend/features/partner/services/mock_partner_morning_report_service.dart';

void main() {
  const responseBody = {
    'target_date': '2026-09-20',
    'pregnancy_week': 29,
    'condition_summary': ['피로감 높음', '허리 통증 높음'],
    'planned_activities': ['장보기', '빨래'],
    'guide_summaries': {
      'meal': '현미밥과 나물',
      'household': '무거운 빨래 나누기',
      'health': '허리 스트레칭',
      'sleep': '조명 낮추기',
    },
  };

  test('API 응답을 남편 오전 리포트 모델로 파싱한다', () async {
    final service = _apiService(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode(responseBody)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final report = await service.fetch(DateTime(2026, 9, 20));

    expect(report?.targetDate, DateTime(2026, 9, 20));
    expect(report?.pregnancyWeek, 29);
    expect(report?.conditionSummary, ['피로감 높음', '허리 통증 높음']);
    expect(report?.guideSummaries['meal'], '현미밥과 나물');
  });

  test('API 404 응답은 빈 리포트로 처리한다', () async {
    final service = _apiService((_) async => http.Response('', 404));

    expect(await service.fetch(DateTime(2026, 9, 20)), isNull);
  });

  test('Controller는 loading에서 data 상태로 전환한다', () async {
    final report = PartnerMorningReport.fromJson(responseBody);
    final controller = PartnerMorningReportController(
      service: MockPartnerMorningReportService(report: report),
      date: report.targetDate,
    );
    final states = <PartnerMorningReportState>[];
    controller.addListener(() => states.add(controller.state));

    await controller.load();

    expect(states, [
      PartnerMorningReportState.loading,
      PartnerMorningReportState.data,
    ]);
    expect(controller.report, same(report));
  });

  testWidgets('화면은 주차·날짜·요약을 모델 값으로 표시한다', (tester) async {
    final report = PartnerMorningReport.fromJson(responseBody);
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerMorningReportScreen(
          date: '2026-09-20',
          service: MockPartnerMorningReportService(report: report),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('임신 29주차예요'), findsOneWidget);
    expect(find.text('9월 20일 컨디션 요약'), findsOneWidget);
    expect(find.text('피로감 높음 · 허리 통증 높음'), findsOneWidget);
    expect(find.text('장보기 · 빨래'), findsOneWidget);
    expect(find.text('현미밥과 나물'), findsOneWidget);
    expect(find.text('조명 낮추기'), findsOneWidget);
    expect(find.textContaining('희선님'), findsNothing);
  });
}

ApiPartnerMorningReportService _apiService(
  Future<http.Response> Function(http.Request) handler,
) => ApiPartnerMorningReportService(
  client: ApiClient(
    httpClient: MockClient(handler),
    baseUrl: 'http://localhost:8000',
  ),
);
