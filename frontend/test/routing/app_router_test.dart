import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    ProfileStore.instance.reset();
    AuthSessionStore.instance.update(
      accountId: 'wife-${DateTime.now().microsecondsSinceEpoch}',
      roles: {ActiveRole.wife},
      husbandLinked: false,
    );
  });

  test('아내와 남편 Route Tree가 V2 경로로 분리된다', () {
    expect(
      AppRouter.productRoutes,
      containsAll([
        RouteNames.entry,
        RouteNames.wifeHome,
        RouteNames.wifeCalendar,
        RouteNames.husbandCalendar,
        RouteNames.husbandDailyReportPattern,
        RouteNames.roleSwitchPattern,
      ]),
    );
    expect(RouteNames.husbandCalendar, startsWith('/husband/'));
    expect(RouteNames.partnerCalendar, RouteNames.husbandCalendar);
  });

  test('프로필 미완료 아내는 최초 단계에서 시작한다', () {
    expect(AppRouter.resolveLocation('/'), RouteNames.profileSetup);
    expect(
      AppRouter.resolveLocation(RouteNames.wifeHome),
      RouteNames.profileSetup,
    );
    expect(
      AppRouter.resolveLocation('/wife/profile/onboarding/5'),
      RouteNames.profileSetup,
    );
  });

  test('아내에게 다른 역할 URL을 직접 입력해도 역할이 바뀌지 않는다', () {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    expect(
      AppRouter.resolveLocation(RouteNames.husbandCalendar),
      RouteNames.wifeHome,
    );
    expect(ActiveRoleStore.instance.value, ActiveRole.wife);
  });

  test('연결된 남편은 캘린더 홈과 유효한 상세 URL을 복원한다', () {
    AuthSessionStore.instance.update(
      accountId: 'husband-linked',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );
    expect(AppRouter.resolveLocation('/'), RouteNames.husbandCalendar);
    expect(
      AppRouter.resolveLocation('/husband/report/daily/2026-09-17'),
      '/husband/report/daily/2026-09-17',
    );
    expect(
      AppRouter.resolveLocation('/husband/requests/request-123'),
      '/husband/requests/request-123',
    );
    expect(
      AppRouter.resolveLocation(RouteNames.wifeHome),
      RouteNames.husbandCalendar,
    );
    expect(
      AppRouter.resolveLocation('/husband/report/daily/invalid'),
      RouteNames.husbandCalendar,
    );
  });

  testWidgets('연결되지 않은 남편은 초대 필요 안내만 본다', (tester) async {
    AuthSessionStore.instance.update(
      accountId: 'husband-unlinked',
      roles: {ActiveRole.husband},
      husbandLinked: false,
    );
    expect(
      AppRouter.resolveLocation(RouteNames.husbandCalendar),
      RouteNames.entry,
    );
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.husbandCalendar,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    expect(find.text('초대가 필요합니다'), findsOneWidget);
  });

  test('로그인 상태와 표시 역할을 따로 복원하고 접근권을 다시 확인한다', () {
    final auth = AuthSessionStore.instance;
    final roles = ActiveRoleStore.instance;
    auth.update(
      accountId: 'dual-role',
      roles: {ActiveRole.wife, ActiveRole.husband},
      husbandLinked: true,
    );
    expect(roles.value, isNull);
    expect(roles.switchTo(ActiveRole.husband, auth), isTrue);
    roles.restoreFor(auth);
    expect(roles.value, ActiveRole.husband);
    expect(auth.accountId, 'dual-role');

    auth.update(
      accountId: 'dual-role',
      roles: {ActiveRole.wife},
      husbandLinked: false,
    );
    expect(roles.value, ActiveRole.wife);
    expect(roles.switchTo(ActiveRole.husband, auth), isFalse);
  });

  test('직접 URL과 외부 role switch URL은 현재 역할을 바꾸지 않는다', () {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    final auth = AuthSessionStore.instance;
    final roles = ActiveRoleStore.instance;
    auth.update(
      accountId: 'dual-direct-url',
      roles: {ActiveRole.wife, ActiveRole.husband},
      husbandLinked: true,
    );
    expect(roles.switchTo(ActiveRole.wife, auth), isTrue);

    expect(
      AppRouter.resolveLocation(RouteNames.husbandNotifications),
      RouteNames.wifeHome,
    );
    expect(
      AppRouter.resolveLocation(RouteNames.roleSwitch('husband')),
      RouteNames.wifeHome,
    );
    expect(roles.value, ActiveRole.wife);
    expect(auth.accountId, 'dual-direct-url');
  });

  test('잘못된 역할의 최초 URL은 현재 역할 Home route로 정규화한다', () {
    AuthSessionStore.instance.update(
      accountId: 'husband-initial-guard',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );

    final routes = AppRouter.onGenerateInitialRoutes(RouteNames.wifeHome);

    expect(routes.single.settings.name, RouteNames.husbandCalendar);
    expect(ActiveRoleStore.instance.value, ActiveRole.husband);
  });

  testWidgets('식사 상세 URL은 Placeholder 없이 해당 끼니 상세를 복원한다', (tester) async {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.mealDetail('dinner'),
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meal-recommendation-detail')),
      findsOneWidget,
    );
    expect(find.text('저녁'), findsOneWidget);
    expect(find.text('식사 상세 화면 준비 중'), findsNothing);
  });

  testWidgets('명시적 전환은 대상 역할 홈으로 가고 이전 stack을 제거한다', (tester) async {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    AuthSessionStore.instance.update(
      accountId: 'dual-widget',
      roles: {ActiveRole.wife, ActiveRole.husband},
      husbandLinked: true,
    );
    expect(
      ActiveRoleStore.instance.switchTo(
        ActiveRole.wife,
        AuthSessionStore.instance,
      ),
      isTrue,
    );

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  AppRouter.switchRole(context, ActiveRole.husband),
              child: const Text('전환'),
            ),
          ),
        ),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.tap(find.text('전환'));
    await tester.pumpAndSettle();
    expect(ActiveRoleStore.instance.value, ActiveRole.husband);
    expect(AuthSessionStore.instance.accountId, 'dual-widget');
    expect(AuthSessionStore.instance.roles, {
      ActiveRole.wife,
      ActiveRole.husband,
    });
    expect(find.text('컨디션 캘린더'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('전환'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('남편에서 아내로 전환하면 아내 Home과 Bottom Navigation으로 교체한다', (
    tester,
  ) async {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    final auth = AuthSessionStore.instance;
    auth.update(
      accountId: 'dual-husband-to-wife',
      roles: {ActiveRole.wife, ActiveRole.husband},
      husbandLinked: true,
    );
    expect(ActiveRoleStore.instance.switchTo(ActiveRole.husband, auth), isTrue);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppRouter.switchRole(context, ActiveRole.wife),
              child: const Text('아내로 전환'),
            ),
          ),
        ),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.tap(find.text('아내로 전환'));
    await tester.pumpAndSettle();

    expect(ActiveRoleStore.instance.value, ActiveRole.wife);
    expect(auth.accountId, 'dual-husband-to-wife');
    expect(auth.isAuthenticated, isTrue);
    expect(find.text('홈'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('아내로 전환'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
