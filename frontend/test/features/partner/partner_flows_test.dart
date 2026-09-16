import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/planned_activity_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    PlannedActivityStore.instance.clear();
    PartnerRequestStore.instance.clear();
  });

  testWidgets('유효한 초대 링크를 수락하면 Partner Calendar로 이동한다', (tester) async {
    await _pumpRoute(tester, '${RouteNames.invitationEntry}?token=test-token');

    final accept = find.byKey(const ValueKey('accept-invitation-button'));
    await tester.scrollUntilVisible(
      accept,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(accept);
    await tester.pumpAndSettle();

    expect(find.text('2026년 9월'), findsOneWidget);
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

    final confirm = find.byKey(const ValueKey('partner-request-confirm'));
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
      PartnerRequestStore.instance.request('demo-request').status.name,
      'confirmed',
    );

    final complete = find.byKey(const ValueKey('partner-request-complete'));
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

    expect(find.text('가족 분담을 완료했어요'), findsOneWidget);
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
