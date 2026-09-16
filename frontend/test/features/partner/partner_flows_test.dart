import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/planned_activity_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/models/partner_request.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    PlannedActivityStore.instance.clear();
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
  });

  testWidgets('리포트 알림은 해당 날짜 오전 리포트로 연결된다', (tester) async {
    await _pumpRoute(tester, RouteNames.partnerNotifications);

    await tester.tap(
      find.byKey(const ValueKey('notification-report-2026-09-13')),
    );
    await tester.pumpAndSettle();

    expect(find.text('희선님은 임신 28주차예요'), findsOneWidget);
    final context = tester.element(find.byType(PartnerMorningReportScreen));
    expect(
      ModalRoute.of(context)?.settings.name,
      RouteNames.partnerMorningReport('2026-09-13'),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('프로필'), findsNothing);
    expect(find.text('도움 요청 확인하기'), findsNothing);
  });

  testWidgets('Partner Join은 초대 상태만 표시하고 실제 연동을 실행하지 않는다', (tester) async {
    await _pumpRoute(tester, '${RouteNames.partnerJoin}?token=test-token');
    await tester.scrollUntilVisible(
      find.text('초대 수락은 개발 중입니다'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('초대 수락은 개발 중입니다'), findsOneWidget);
    expect(find.text('ThinQ 로그인하고 연결하기'), findsNothing);
  });

  testWidgets('Partner Calendar는 알림과 명시적 상세 CTA만 제공한다', (tester) async {
    await _pumpRoute(tester, RouteNames.partnerCalendar);

    expect(find.byTooltip('알림'), findsOneWidget);
    expect(find.byTooltip('프로필'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('이 날 아침 리포트 보기'), findsOneWidget);
    expect(find.text('실시간 홈캠 신체 정보 보기'), findsOneWidget);
  });

  testWidgets('예정 활동을 선택하고 Mock 루틴을 생성한다', (tester) async {
    await _pumpRoute(tester, RouteNames.activity);

    await tester.tap(find.byKey(const ValueKey('activity-장보기')));
    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(PlannedActivityStore.instance.activities, contains('장보기'));
    expect(find.textContaining('오늘 임신 28주차예요'), findsOneWidget);
  });

  testWidgets('가사 알림에서 요청 상세로 이동하고 확인·완료 처리한다', (tester) async {
    await _pumpRoute(tester, RouteNames.partnerNotifications);

    await tester.tap(
      find.byKey(const ValueKey('notification-request-demo-request')),
    );
    await tester.pumpAndSettle();
    expect(find.text('희선님이 도움을 요청했어요'), findsOneWidget);

    expect(PartnerNotificationStore.instance.unreadCount, 1);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('프로필'), findsNothing);

    final confirm = find.byKey(
      const ValueKey('partner-request-confirm-heavy-grocery'),
    );
    await tester.scrollUntilVisible(
      confirm,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(
      PartnerRequestStore.instance.request('demo-request').tasks.first.status,
      PartnerRequestStatus.confirmed,
    );

    final complete = find.byKey(
      const ValueKey('partner-request-complete-heavy-grocery'),
    );
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '완료했어요'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('완료 처리됐어요'), findsOneWidget);
    expect(find.textContaining('요청 3건 · 확인 1건 · 완료 1건'), findsOneWidget);

    await tester.tap(find.text('캘린더로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('요청 3 · 확인 1 · 완료 1'), findsOneWidget);
  });
}

Future<void> _pumpRoute(WidgetTester tester, String route) async {
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: route,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
    ),
  );
  await tester.pumpAndSettle();
}
