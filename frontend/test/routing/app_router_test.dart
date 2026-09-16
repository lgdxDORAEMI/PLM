import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  const expectedScreenIds = <String, String>{
    RouteNames.profileSetup: 'SCR-W-01',
    RouteNames.wifeProfile: 'SCR-W-01',
    RouteNames.partnerInvite: 'SCR-W-14',
    RouteNames.wifeInvite: 'SCR-W-14',
    '${RouteNames.invitationEntry}?token=test-token': 'SCR-H-06',
    RouteNames.condition: 'SCR-W-02',
    '${RouteNames.condition}?mode=edit': 'SCR-W-02',
    RouteNames.activity: 'SCR-W-03',
    RouteNames.wifeHome: 'SCR-W-04',
    RouteNames.mealGuide: 'SCR-W-05',
    RouteNames.householdGuide: 'SCR-W-06',
    RouteNames.wifeMovement: 'SCR-W-07',
    RouteNames.partnerMovement: 'SCR-W-07',
    RouteNames.healthGuide: 'SCR-W-08',
    RouteNames.sleepGuide: 'SCR-W-09',
    RouteNames.mealChat: 'SCR-W-10',
    '/wife/calendar/report/2026-09-16': 'SCR-W-11',
    RouteNames.wifeCalendar: 'SCR-W-12',
    RouteNames.wifeSettings: 'SCR-W-13',
    '/partner/report/2026-09-16': 'SCR-H-01',
    RouteNames.partnerCalendar: 'SCR-H-02',
    RouteNames.partnerNotifications: 'SCR-H-03',
    '/partner/requests/request-123': 'SCR-H-04',
    RouteNames.partnerProfile: 'SCR-H-05',
  };

  testWidgets('ROUTE_MAP의 모든 내부 경로가 대응 화면을 만든다', (tester) async {
    for (final entry in expectedScreenIds.entries) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          initialRoute: entry.key,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('최초 프로필 등록은 초대를 거쳐 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );

    await tester.tap(find.text('프로필 입력 완료'));
    await tester.pumpAndSettle();
    expect(find.text('SCR-W-14'), findsOneWidget);

    await tester.tap(find.text('링크 보내기 또는 나중에'));
    await tester.pumpAndSettle();
    expect(find.text('SCR-W-04'), findsOneWidget);
  });

  testWidgets('동적 date와 requestId를 화면에 전달한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/partner/requests/request-123',
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('request-123'), findsOneWidget);
  });

  testWidgets('프로필 수정 직접 URL은 저장 후 안전한 Home으로 복귀한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeProfile,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정 저장 후 이전 화면'));
    await tester.pumpAndSettle();
    expect(find.text('SCR-W-04'), findsOneWidget);
  });

  testWidgets('아내 Shell은 서비스 흐름의 네 가지 하단 탭을 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('실시간'), findsOneWidget);
    expect(find.text('챗봇'), findsOneWidget);
    expect(find.text('캘린더'), findsOneWidget);
  });

  test('Bootstrap 상태가 역할별 시작 경로를 결정한다', () {
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.wifeNeedsProfile),
      RouteNames.profileSetup,
    );
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.wifeReady),
      RouteNames.wifeHome,
    );
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.partnerLinked),
      RouteNames.partnerCalendar,
    );
  });

  testWidgets('등록되지 않은 경로는 404 스켈레톤을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/missing',
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('404'), findsOneWidget);
  });
}
