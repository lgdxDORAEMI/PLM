import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/report/screens/daily_report_screen.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
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
}
