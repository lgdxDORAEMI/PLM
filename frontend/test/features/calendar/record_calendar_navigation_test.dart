import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/report/screens/daily_report_screen.dart';
import 'package:plm_frontend/features/calendar/data/calendar_selection_store.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/home/screens/wife_home_screen.dart';
import 'package:plm_frontend/features/report/models/daily_record.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  setUp(() {
    CalendarSelectionStore.instance.reset();
    TodayCareStore.instance.clear();
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    AuthSessionStore.instance.update(
      accountId: 'calendar-wife',
      roles: {ActiveRole.wife},
      husbandLinked: false,
    );
  });

  testWidgets('오늘 리포트 저장은 Home을 초기화하고 Calendar 선택 날짜를 보존한다', (tester) async {
    final today = DateTime.now();
    final date = recordDateKey(today);
    TodayCareStore.instance.save(const ConditionDraft());
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.dailyReport(date),
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const ValueKey('report-save-button'));
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(TodayCareStore.instance.hasTodayCare, isFalse);
    expect(recordDateKey(CalendarSelectionStore.instance.selectedDate!), date);
    expect(find.byType(WifeHomeScreen), findsOneWidget);
  });

  testWidgets('날짜를 선택해 해당 Daily Report로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-09-07')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-detail-2026-09-07')),
      findsOneWidget,
    );

    final reportButton = find.byKey(const ValueKey('calendar-open-report'));
    await tester.scrollUntilVisible(
      reportButton,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('9월 7일 (월)'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(reportButton);
    await tester.pumpAndSettle();
    expect(find.text('오늘 루틴을 모두 마쳤어요'), findsOneWidget);
    final reportContext = tester.element(find.byType(DailyReportScreen));
    expect(
      ModalRoute.of(reportContext)?.settings.name,
      RouteNames.dailyReport('2026-09-07'),
    );
  });

  testWidgets('남편 캘린더에는 홈캠 관련 주의사항 섹션이 없다', (tester) async {
    AuthSessionStore.instance.update(
      accountId: 'calendar-husband',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.partnerCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈캠 관련 주의사항'), findsNothing);
  });

  testWidgets('아내 캘린더에는 홈캠 관련 주의사항 섹션이 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈캠 관련 주의사항'), findsOneWidget);
  });

  testWidgets('Desktop에서는 Calendar와 선택 날짜 상세를 2-column으로 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    final calendar = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-month-panel')),
    );
    final detail = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-detail-2026-09-13')),
    );
    expect(detail.dx, greaterThan(calendar.dx));
    expect((detail.dy - calendar.dy).abs(), lessThan(1));
  });

  testWidgets('아내와 남편 캘린더는 Desktop에서 날짜 셀과 패널 여백을 확대한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('wife-calendar-mobile'),
        initialRoute: RouteNames.wifeCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-day-2026-09-13')))
          .height,
      44,
    );

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('wife-calendar-desktop'),
        initialRoute: RouteNames.wifeCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-day-2026-09-13')))
          .height,
      60,
    );

    AuthSessionStore.instance.update(
      accountId: 'calendar-husband',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('husband-calendar-desktop'),
        initialRoute: RouteNames.partnerCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-day-2026-09-13')))
          .height,
      60,
    );
    expect(tester.takeException(), isNull);
  });
}
