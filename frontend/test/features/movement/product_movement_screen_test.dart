import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  testWidgets('Wife는 Mock 상태를 확인하고 가사 Routine으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeMovement,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('최근 이벤트'), findsOneWidget);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);
    expect(find.text('기기 상태'), findsOneWidget);
    expect(find.text('MediaPipe 실행 안 함'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('movement-mock-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Mock 미리보기 일시 정지'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('movement-mock-switch')));
    await tester.pumpAndSettle();

    final event = find.byKey(const ValueKey('movement-alert-back-load'));
    await tester.ensureVisible(event);
    await tester.pumpAndSettle();
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(find.text('추천 행동'), findsOneWidget);
    expect(find.textContaining('의료적 판단'), findsOneWidget);

    final confirmButton = find.byKey(
      const ValueKey('movement-alert-confirm-back-load'),
    );
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(find.text('확인함'), findsNWidgets(2));

    final householdButton = find.byKey(const ValueKey('movement-to-household'));
    await tester.fling(find.byType(ListView), const Offset(0, 1000), 1200);
    await tester.pumpAndSettle();
    await tester.tap(householdButton);
    await tester.pumpAndSettle();
    expect(find.text('오늘은 허리 통증이 있는 날'), findsOneWidget);
  });

  testWidgets('Partner는 Calendar CTA로 진입하고 Bottom Navigation이 없다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.partnerMovement,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('뒤로 가기'), findsOneWidget);
    expect(find.byKey(const ValueKey('movement-to-household')), findsNothing);
    expect(find.text('Local Mock Data'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 9월'), findsOneWidget);
  });
}
