import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  testWidgets('Alert를 확인하고 가사 Routine으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeMovement,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('movement-monitoring-switch')));
    await tester.pumpAndSettle();
    expect(find.text('mock 감지가 꺼져 있어요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('movement-alert-back-load')));
    await tester.pumpAndSettle();
    expect(find.text('추천 행동'), findsOneWidget);
    expect(find.textContaining('의료적 판단'), findsOneWidget);

    final confirmButton = find.byKey(
      const ValueKey('movement-alert-confirm-back-load'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.text('확인함'), findsOneWidget);

    final householdButton = find.byKey(const ValueKey('movement-to-household'));
    await tester.ensureVisible(householdButton);
    await tester.tap(householdButton);
    await tester.pumpAndSettle();
    expect(find.text('오늘은 허리 통증이 있는 날'), findsOneWidget);
  });
}
