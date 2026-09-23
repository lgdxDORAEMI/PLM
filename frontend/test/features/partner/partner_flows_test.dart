import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/design_system/components/app_card.dart';
import 'package:plm_frontend/design_system/tokens/app_colors.dart';
import 'package:plm_frontend/features/calendar/data/calendar_selection_store.dart';
import 'package:plm_frontend/features/invitation/data/partner_connection_store.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/partner/models/partner_request.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/features/settings/controllers/app_text_scale_store.dart';
import 'package:plm_frontend/features/settings/models/app_font_size.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  setUp(() {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    PartnerConnectionStore.instance.reset();
    CalendarSelectionStore.instance.reset();
    AppTextScaleStore.instance.reset();
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
    expect(find.text('컨디션 리포트'), findsOneWidget);
    expect(find.text('가사 요청'), findsOneWidget);
    expect(find.text('루틴 변경'), findsOneWidget);

    final reportCard = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const ValueKey('notification-report-2026-09-13')),
        matching: find.byType(AppCard),
      ),
    );
    final requestCard = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const ValueKey('notification-request-demo-request')),
        matching: find.byType(AppCard),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-report-2026-09-12')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final readReportCard = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const ValueKey('notification-report-2026-09-12')),
        matching: find.byType(AppCard),
      ),
    );
    expect(reportCard.backgroundColor, AppColors.infoBackground);
    expect(requestCard.backgroundColor, AppColors.categoryHouseholdBackground);
    expect(reportCard.borderColor, AppColors.primary600);
    expect(readReportCard.borderColor, AppColors.borderSubtle);

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

    expect(find.text('임신 28주차예요'), findsOneWidget);
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
    expect(find.byTooltip('메뉴'), findsOneWidget);
    expect(find.byTooltip('프로필'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('이 날 리포트 보기'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-day-2026-09-13')))
          .height,
      44,
    );
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('calendar-month-panel')))
          .dy,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });

  testWidgets('남편 메뉴에는 글자 크기 조정 기능만 표시한다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandCalendar);

    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();

    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('프로필 수정'), findsNothing);
    expect(find.text('남편 초대하기'), findsNothing);
    expect(find.text('LG전자  ·  이용약관  ·  개인정보처리방침'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('font-size-large')));
    await tester.pump();
    expect(AppTextScaleStore.instance.value, AppFontSize.large);
  });

  testWidgets('가사 요청은 집안일별로 확인·완료하고 상태 색상을 구분한다', (tester) async {
    await _pumpRoute(tester, RouteNames.husbandNotifications);
    await tester.tap(
      find.byKey(const ValueKey('notification-request-demo-request')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026-09-13 요청 3건'), findsOneWidget);

    expect(find.text('오늘 요청한 이유'), findsNothing);
    expect(find.text('참고 정보'), findsNothing);
    expect(find.textContaining('요청 번호'), findsNothing);
    expect(find.text('demo-request'), findsNothing);
    expect(find.textContaining('확인 상태가 희선님 화면에 반영'), findsNothing);

    const taskIds = ['heavy-grocery', 'table-cleanup', 'water-plants'];
    final requestStore = PartnerRequestStore.instance;

    // 항목 하나만 확인해도 같은 요청의 다른 항목은 그대로여야 한다(카드별 개별 상태 관리).
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
    expect(
      tester
          .widget<AppCard>(
            find.byKey(ValueKey('partner-request-task-${taskIds[1]}')),
          )
          .backgroundColor,
      AppColors.surface,
    );

    await _tapTaskAction(tester, 'husband-request-complete-${taskIds.first}');
    await _acceptCompletionDialog(tester);
    // 완료한 항목은 목록 아래로 이동하고 나머지 항목은 바로 처리할 수 있어야 한다.
    expect(
      requestStore.request('demo-request').tasks.map((task) => task.status),
      [
        PartnerRequestStatus.completed,
        PartnerRequestStatus.requested,
        PartnerRequestStatus.requested,
      ],
    );

    for (final taskId in taskIds.skip(1)) {
      await _tapTaskAction(tester, 'husband-request-confirm-$taskId');
      await _tapTaskAction(tester, 'husband-request-complete-$taskId');
      await _acceptCompletionDialog(tester);
    }

    expect(find.text('완료됨'), findsNWidgets(3));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('가사 알림을 열면 알림 날짜의 요청만 상태순으로 표시한다', (tester) async {
    final store = PartnerRequestStore.instance;
    store.request('demo-request');
    store.save(
      PartnerRequestData(
        id: 'another-request',
        requester: '희선님',
        reason: '추가로 도움이 필요해요.',
        tasks: [
          PartnerRequestTask(
            id: 'another-task',
            title: '추가 가사 요청',
            status: PartnerRequestStatus.confirmed,
          ),
        ],
        supportingInfo: '',
        recordDate: '2026-09-13',
        requestedAt: DateTime(2026, 9, 13, 9),
      ),
    );
    store.save(
      const PartnerRequestData(
        id: 'old-request',
        requester: '희선님',
        reason: '어제 요청이에요.',
        tasks: [PartnerRequestTask(id: 'old-task', title: '어제 가사 요청')],
        supportingInfo: '',
        recordDate: '2026-09-12',
      ),
    );

    await _pumpRoute(tester, RouteNames.husbandNotifications);
    await tester.tap(
      find.byKey(const ValueKey('notification-request-demo-request')),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-09-13 요청 4건'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('추가 가사 요청'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('추가 가사 요청'), findsOneWidget);
    expect(find.text('어제 가사 요청'), findsNothing);
    expect(find.text('확인됨'), findsWidgets);
  });
}

Future<void> _tapTaskAction(WidgetTester tester, String key) async {
  final action = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    action,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
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
