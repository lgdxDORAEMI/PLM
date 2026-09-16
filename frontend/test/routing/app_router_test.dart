import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  const expectedRequirementIds = <String, String>{
    RouteNames.profileSetup: '프로필 설정',
    RouteNames.wifeProfile: '프로필 수정',
    RouteNames.partnerInvite: 'W-INVITE-001',
    RouteNames.wifeInvite: 'W-INVITE-001',
    '${RouteNames.invitationEntry}?token=test-token': 'H-INVITE-001',
    RouteNames.condition: 'W-COND-001',
    '${RouteNames.condition}?mode=edit': 'W-COND-001',
    RouteNames.activity: 'W-ACT-001',
    RouteNames.wifeHome: 'W-ROUTINE-001',
    RouteNames.mealGuide: 'W-MEAL-001',
    RouteNames.householdGuide: 'W-HOUSE-001',
    RouteNames.wifeMovement: 'W-MOTION-001',
    RouteNames.partnerMovement: 'H-MOTION-001',
    RouteNames.healthGuide: 'W-HEALTH-001',
    RouteNames.sleepGuide: 'W-SLEEP-001',
    RouteNames.mealChat: 'W-CHAT-001',
    '/wife/calendar/report/2026-09-16': 'W-REPORT-001',
    RouteNames.wifeCalendar: 'W-CAL-001',
    RouteNames.wifeSettings: 'W-SETTING-001',
    '/partner/report/2026-09-16': 'H-REPORT-001',
    RouteNames.partnerCalendar: 'H-CAL-001',
    RouteNames.partnerNotifications: 'H-NOTI-001',
    '/partner/requests/request-123': 'H-REQUEST-001',
    RouteNames.partnerProfile: 'H-PROFILE-001',
  };

  testWidgets('ROUTE_MAP의 모든 내부 경로가 대응 화면을 만든다', (tester) async {
    for (final entry in expectedRequirementIds.entries) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          initialRoute: entry.key,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(entry.value),
        findsOneWidget,
        reason: entry.key,
      );
    }
  });

  testWidgets('최초 프로필 등록은 초대를 거쳐 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );

    await tester.tap(find.byKey(const Key('due-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.textContaining('나이와 임신 전'), findsOneWidget);

    final bodyFields = find.byType(TextField);
    await tester.enterText(bodyFields.at(0), '32');
    await tester.enterText(bodyFields.at(1), '165');
    await tester.enterText(bodyFields.at(2), '55');
    await _tapNext(tester);
    expect(find.text('첫 출산이신가요?'), findsOneWidget);

    await tester.tap(find.text('초산이에요'));
    await _tapNext(tester);
    expect(find.text('아기는 몇 명인가요?'), findsOneWidget);
    await tester.tap(find.text('한 명이에요 (단태)'));
    await _tapNext(tester);
    expect(find.text('알레르기가 있나요?'), findsOneWidget);
    await _tapNext(tester);
    expect(find.text('병원에서 주의받은 게 있나요?'), findsOneWidget);
    await _tapNext(tester);
    expect(find.text('입력한 내용을 확인해 주세요'), findsOneWidget);

    await tester.ensureVisible(find.text('완료하고 시작하기'));
    await tester.tap(find.text('완료하고 시작하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('W-INVITE-001'), findsOneWidget);

    await tester.tap(find.text('링크 보내기 또는 나중에'));
    await tester.pumpAndSettle();
    expect(find.textContaining('W-ROUTINE-001'), findsOneWidget);
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

  testWidgets('Profile 단계의 Back은 이전 입력 단계로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );

    await tester.tap(find.byKey(const Key('due-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _tapNext(tester);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();

    expect(find.text('출산예정일을 알려주세요'), findsOneWidget);
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
    for (var step = 0; step < 6; step += 1) {
      await _tapNext(tester);
    }
    await tester.ensureVisible(find.text('수정 완료'));
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();
    expect(find.textContaining('W-ROUTINE-001'), findsOneWidget);
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
    expect(find.textContaining('등록되지 않은 경로입니다: /missing'), findsOneWidget);
  });
}

Future<void> _tapNext(WidgetTester tester) async {
  final button = find.text('다음');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
