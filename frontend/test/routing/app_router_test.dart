import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  const expectedScreenIds = <String, String>{
    RouteNames.profileSetup: 'SCR-W-01',
    RouteNames.partnerInvite: 'SCR-W-14',
    RouteNames.invitationEntry: 'SCR-H-06',
    RouteNames.condition: 'SCR-W-02',
    RouteNames.activity: 'SCR-W-03',
    RouteNames.wifeHome: 'SCR-W-04',
    RouteNames.mealGuide: 'SCR-W-05',
    RouteNames.householdGuide: 'SCR-W-06',
    RouteNames.movement: 'SCR-W-07',
    RouteNames.healthGuide: 'SCR-W-08',
    RouteNames.sleepGuide: 'SCR-W-09',
    RouteNames.mealChat: 'SCR-W-10',
    RouteNames.dailyReport: 'SCR-W-11',
    RouteNames.wifeCalendar: 'SCR-W-12',
    RouteNames.wifeSettings: 'SCR-W-13',
    RouteNames.partnerMorningReport: 'SCR-H-01',
    RouteNames.partnerCalendar: 'SCR-H-02',
    RouteNames.partnerNotifications: 'SCR-H-03',
    RouteNames.partnerRequest: 'SCR-H-04',
    RouteNames.partnerProfile: 'SCR-H-05',
  };

  testWidgets('ROUTE_MAP의 모든 제품 경로가 화면을 만든다', (tester) async {
    for (final entry in expectedScreenIds.entries) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          initialRoute: entry.key,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('프로필에서 초대를 거쳐 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(onGenerateRoute: AppRouter.onGenerateRoute),
    );

    await tester.tap(find.text('프로필 입력 완료'));
    await tester.pumpAndSettle();
    expect(find.text('SCR-W-14'), findsOneWidget);

    await tester.tap(find.text('홈으로 이동'));
    await tester.pumpAndSettle();
    expect(find.text('SCR-W-04'), findsOneWidget);
  });

  testWidgets('동적 report/request 경로를 대응 화면으로 복원한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/partner/requests/request-123',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SCR-H-04'), findsOneWidget);
  });

  testWidgets('등록되지 않은 경로는 404 스켈레톤을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/missing',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('404'), findsOneWidget);
  });
}
