import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/health/screens/health_guide_screen.dart';
import 'package:plm_frontend/features/household/screens/household_guide_screen.dart';
import 'package:plm_frontend/features/meal/screens/meal_guide_screen.dart';
import 'package:plm_frontend/features/sleep/screens/sleep_guide_screen.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  final guides = <String, Widget>{
    '식사': const MealGuideScreen(),
    '가사': const HouseholdGuideScreen(),
    '건강': const HealthGuideScreen(),
    '수면': const SleepGuideScreen(),
  };

  for (final entry in guides.entries) {
    testWidgets('${entry.key} 가이드에서 홈 탭은 홈 첫 화면으로 이동한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: entry.value,
          routes: {
            RouteNames.wifeHome: (_) => const Scaffold(body: Text('홈 첫 화면')),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('홈').last);
      await tester.pumpAndSettle();

      expect(find.text('홈 첫 화면'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    });
  }

  testWidgets('데스크톱 가이드의 홈 메뉴도 홈 첫 화면으로 이동한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: const MealGuideScreen(),
        routes: {
          RouteNames.wifeHome: (_) => const Scaffold(body: Text('홈 첫 화면')),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();

    expect(find.text('홈 첫 화면'), findsOneWidget);
  });
}
