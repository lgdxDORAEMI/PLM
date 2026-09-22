import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    AppConfig.previewMode = true;
    ProfileStore.instance.reset();
    TodayCareStore.instance.clear();
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );
  });
  tearDown(() {
    AppConfig.previewMode = false;
    TodayCareStore.instance.clear();
  });

  test('미리보기에서는 연동 정보 없이 아내·남편 화면 경로를 유지한다', () {
    final paths = [
      RouteNames.entry,
      RouteNames.wifeHome,
      RouteNames.profileSetup,
      RouteNames.wifeProfile,
      RouteNames.wifeInvite,
      RouteNames.condition,
      RouteNames.activity,
      RouteNames.mealGuide,
      RouteNames.mealDetail('dinner'),
      RouteNames.householdGuide,
      RouteNames.healthGuide,
      RouteNames.sleepGuide,
      RouteNames.wifeCalendar,
      RouteNames.dailyReport('2026-09-13'),
      RouteNames.mealChat,
      RouteNames.husbandCalendar,
      RouteNames.husbandNotifications,
      RouteNames.husbandMorningReport('2026-09-13'),
      RouteNames.husbandDailyReport('2026-09-13'),
      RouteNames.husbandRequest('demo-request'),
      RouteNames.husbandRequestResult('demo-request'),
    ];
    for (final path in paths) {
      expect(AppRouter.resolveLocation(path), path);
    }
  });

  testWidgets('미리보기 Home은 프로필·컨디션 입력 없이 루틴을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-routine-success')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const ValueKey('home-routine-success')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('routine-card-meal')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('routine-card-meal')), findsOneWidget);
  });

  testWidgets('미리보기에서 남편 요청 상세를 직접 확인한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.husbandRequest('demo-request'),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('partner-request-content')),
      findsOneWidget,
    );
  });
}
