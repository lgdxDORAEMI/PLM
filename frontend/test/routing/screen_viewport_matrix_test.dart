import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/debug/empty_data_preview_store.dart';
import 'package:plm_frontend/features/invitation/data/partner_connection_store.dart';
import 'package:plm_frontend/features/calendar/data/calendar_selection_store.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/features/profile/screens/profile_setup_screen.dart';
import 'package:plm_frontend/features/settings/models/app_font_size.dart';
import 'package:plm_frontend/features/settings/widgets/app_text_scale_frame.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(_useWifeSession);

  final routes = <String>[
    RouteNames.entry,
    RouteNames.profileSetup,
    RouteNames.wifeProfile,
    RouteNames.partnerInvite,
    RouteNames.wifeInvite,
    RouteNames.wifeMenu,
    RouteNames.wifeSettings,
    RouteNames.wifeHome,
    RouteNames.condition,
    RouteNames.activity,
    RouteNames.mealGuide,
    RouteNames.householdGuide,
    RouteNames.healthGuide,
    RouteNames.sleepGuide,
    RouteNames.mealChat,
    RouteNames.dailyReport('2026-09-13'),
    RouteNames.wifeCalendar,
    RouteNames.wifeMovement,
    RouteNames.partnerJoin,
    RouteNames.partnerMorningReport('2026-09-13'),
    RouteNames.partnerCalendar,
    RouteNames.husbandMenu,
    RouteNames.partnerNotifications,
    RouteNames.partnerRequest('demo-request'),
    RouteNames.partnerMovement,
  ];

  for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
    testWidgets('화면 Route 전체가 ${width.toInt()}px에서 overflow 없이 열린다', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PartnerConnectionStore.instance.reset();
      CalendarSelectionStore.instance.reset();
      ProfileStore.instance.reset();

      // 직접 URL 복원을 함께 검사해 얕은 화면 진입 누락을 찾는다.
      for (final route in routes) {
        if (route.startsWith('/husband/')) {
          _useHusbandSession();
        } else {
          _useWifeSession();
        }
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$width:$route'),
            initialRoute: route,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
            builder: (context, child) => AppTextScaleFrame(
              appScale: AppFontSize.large.scale,
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width: $route');
        expect(find.byType(Scaffold), findsWidgets, reason: route);
        if (route.startsWith('/husband/')) {
          expect(
            find.byTooltip('메뉴'),
            route == RouteNames.husbandMenu ? findsNothing : findsOneWidget,
            reason: route,
          );
          expect(find.byType(NavigationBar), findsNothing, reason: route);
        }
      }
    });
  }

  testWidgets('조회 화면 전체가 빈 데이터 미리보기를 표시한다', (tester) async {
    final previewStore = EmptyDataPreviewStore.instance;
    previewStore.reset();
    addTearDown(previewStore.reset);
    final startedAt = DateTime(2026, 9, 18, 12);
    for (var count = 0; count < 5; count += 1) {
      previewStore.registerTitleTap(
        now: startedAt.add(Duration(milliseconds: count)),
      );
    }

    final dataRoutes = <String>[
      RouteNames.wifeHome,
      RouteNames.mealGuide,
      RouteNames.householdGuide,
      RouteNames.healthGuide,
      RouteNames.sleepGuide,
      RouteNames.mealChat,
      RouteNames.dailyReport('2026-09-13'),
      RouteNames.wifeCalendar,
      RouteNames.wifeMovement,
      RouteNames.partnerMorningReport('2026-09-13'),
      RouteNames.partnerCalendar,
      RouteNames.partnerNotifications,
      RouteNames.partnerRequest('demo-request'),
      RouteNames.husbandRequestResult('demo-request'),
      RouteNames.partnerMovement,
    ];

    for (final route in dataRoutes) {
      if (route.startsWith('/husband/')) {
        _useHusbandSession();
      } else {
        _useWifeSession();
      }
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('empty:$route'),
          initialRoute: route,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('empty-data-preview')),
        findsOneWidget,
        reason: route,
      );
      expect(tester.takeException(), isNull, reason: route);
    }
  });

  testWidgets('Menu 이전 경로와 연동 상태가 내부 Route 상태와 일치한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.menu(returnLocation: RouteNames.mealGuide),
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('partner-unlinked-state')),
      findsOneWidget,
    );
    PartnerConnectionStore.instance.markLinked();
    await tester.pump();
    expect(find.byKey(const ValueKey('partner-linked-state')), findsOneWidget);
    expect(find.text('남편 초대하기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 끼니를 볼까요?'), findsOneWidget);
    PartnerConnectionStore.instance.reset();
  });

  testWidgets('Menu 프로필 헤더를 탭하면 수정 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeMenu,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('희선님'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('주요 화면은 390px·기기 200%·앱 크게에서 렌더링된다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final route in [
      RouteNames.wifeHome,
      RouteNames.wifeMenu,
      RouteNames.wifeCalendar,
      RouteNames.partnerCalendar,
      RouteNames.partnerRequest('demo-request'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('scaled:$route'),
          initialRoute: route,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: AppTextScaleFrame(
              appScale: AppFontSize.large.scale,
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}

void _useWifeSession() {
  ProfileStore.instance.save(ProfileDraft.mockEdit());
  AuthSessionStore.instance.update(
    accountId: 'viewport-wife',
    roles: {ActiveRole.wife},
    husbandLinked: false,
  );
}

void _useHusbandSession() {
  AuthSessionStore.instance.update(
    accountId: 'viewport-husband',
    roles: {ActiveRole.husband},
    husbandLinked: true,
  );
}
