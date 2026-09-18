import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/components/app_card.dart';
import 'package:plm_frontend/design_system/tokens/app_colors.dart';
import 'package:plm_frontend/features/calendar/data/calendar_selection_store.dart';
import 'package:plm_frontend/features/invitation/data/partner_connection_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/models/partner_request.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    PartnerConnectionStore.instance.reset();
    CalendarSelectionStore.instance.reset();
    AuthSessionStore.instance.update(
      accountId: 'husband-test',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );
  });

  testWidgets('알림은 오전 리포트·가사 요청·루틴 변경 3종을 표시한다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandNotifications);

    expect(find.text('오늘 아침 리포트가 도착했어요'), findsOneWidget);
    expect(find.text('가사 요청이 도착했어요'), findsOneWidget);
    expect(find.text('오늘 루틴이 변경됐어요'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notification-routine-2026-09-13')),
    );
    await tester.pumpAndSettle();
    expect(find.text('컨디션 캘린더'), findsOneWidget);
    expect(CalendarSelectionStore.instance.selectedDate, DateTime(2026, 9, 13));
  });

  testWidgets('오전 리포트 알림은 해당 날짜의 읽기 전용 화면으로 연결된다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandNotifications);
    await tester.tap(
      find.byKey(const ValueKey('notification-report-2026-09-13')),
    );
    await tester.pumpAndSettle();

    expect(find.text('희선님은 임신 28주차예요'), findsOneWidget);
    final context = tester.element(find.byType(PartnerMorningReportScreen));
    expect(
      ModalRoute.of(context)?.settings.name,
      RouteNames.husbandMorningReport('2026-09-13'),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('프로필'), findsNothing);
  });

  testWidgets('ThinQ 초대 검증 성공 후 남편 캘린더로 바로 진입한다', (tester) async {
    AuthSessionStore.instance.update(
      accountId: 'husband-invited',
      roles: {ActiveRole.husband},
      husbandLinked: false,
    );
    await _pumpRoute(tester, RouteNames.invitation(token: 'test-token'));

    expect(PartnerConnectionStore.instance.isLinked, isTrue);
    expect(ActiveRoleStore.instance.value, ActiveRole.husband);
    expect(AuthSessionStore.instance.accountId, 'husband-invited');
    expect(AuthSessionStore.instance.roles, {ActiveRole.husband});
    expect(find.text('컨디션 캘린더'), findsOneWidget);
  });

  testWidgets('아내 계정에서 초대 URL을 열어도 남편 역할 권한을 추가하지 않는다', (tester) async {
    AuthSessionStore.instance.update(
      accountId: 'wife-invitation-url',
      roles: {ActiveRole.wife},
      husbandLinked: false,
    );
    await _pumpRoute(tester, RouteNames.invitation(token: 'test-token'));

    expect(AuthSessionStore.instance.accountId, 'wife-invitation-url');
    expect(AuthSessionStore.instance.roles, {ActiveRole.wife});
    expect(ActiveRoleStore.instance.value, ActiveRole.wife);
    expect(find.text('컨디션 캘린더'), findsNothing);
  });

  testWidgets('남편 Home은 캘린더이며 Bottom Navigation과 프로필이 없다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandCalendar);

    expect(find.byTooltip('알림'), findsOneWidget);
    expect(find.byTooltip('프로필'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('이 날 리포트 보기'), findsOneWidget);
  });

  testWidgets('가사 요청은 집안일별로 확인·완료하고 상태 색상을 구분한다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandNotifications);
    await tester.tap(
      find.byKey(const ValueKey('notification-request-demo-request')),
    );
    await tester.pumpAndSettle();

    const taskIds = ['heavy-grocery', 'table-cleanup', 'water-plants'];
    final requestStore = PartnerRequestStore.instance;

    await _tapTaskAction(tester, 'husband-request-confirm-${taskIds.first}');
    expect(
      requestStore.request('demo-request').tasks.map((task) => task.status),
      [
        PartnerRequestStatus.confirmed,
        PartnerRequestStatus.requested,
        PartnerRequestStatus.requested,
      ],
    );
    expect(
      tester
          .widget<AppCard>(
            find.byKey(ValueKey('partner-request-task-${taskIds.first}')),
          )
          .backgroundColor,
      AppColors.infoBackground,
    );

    await _tapTaskAction(tester, 'husband-request-complete-${taskIds.first}');
    await _acceptCompletionDialog(tester);
    expect(find.text('가사 요청을 완료했어요'), findsNothing);
    expect(
      tester
          .widget<AppCard>(
            find.byKey(ValueKey('partner-request-task-${taskIds.first}')),
          )
          .backgroundColor,
      AppColors.successBackground,
    );

    for (final taskId in taskIds.skip(1)) {
      await _tapTaskAction(tester, 'husband-request-confirm-$taskId');
      await _tapTaskAction(tester, 'husband-request-complete-$taskId');
      await _acceptCompletionDialog(tester);
    }

    expect(find.text('가사 요청을 완료했어요'), findsOneWidget);
    expect(find.text('반영 위치'), findsOneWidget);
    expect(find.text('3건'), findsNWidgets(3));
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('캘린더로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('컨디션 캘린더'), findsOneWidget);
  });
}

Future<void> _tapTaskAction(WidgetTester tester, String key) async {
  final action = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    action,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _acceptCompletionDialog(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '완료했어요'),
    ),
  );
  await tester.pumpAndSettle();
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
