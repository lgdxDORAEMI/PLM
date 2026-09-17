import 'package:flutter/material.dart';

import '../features/calendar/screens/wife_calendar_screen.dart';
import '../features/condition/screens/activity_screen.dart';
import '../features/condition/screens/condition_screen.dart';
import '../features/entry/screens/entry_screen.dart';
import '../features/health/screens/health_guide_screen.dart';
import '../features/home/screens/wife_home_screen.dart';
import '../features/household/screens/household_guide_screen.dart';
import '../features/meal/screens/meal_chat_screen.dart';
import '../features/meal/screens/meal_guide_screen.dart';
import '../features/menu/screens/wife_menu_screen.dart';
import '../features/movement/product_movement_screen.dart';
import '../features/partner/screens/invitation_entry_screen.dart';
import '../features/partner/screens/partner_calendar_screen.dart';
import '../features/partner/screens/partner_morning_report_screen.dart';
import '../features/partner/screens/partner_notifications_screen.dart';
import '../features/partner/screens/partner_request_screen.dart';
import '../features/profile/screens/partner_invite_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import '../features/report/screens/daily_report_screen.dart';
import '../features/settings/screens/wife_settings_screen.dart';
import '../features/sleep/screens/sleep_guide_screen.dart';
import 'route_context.dart';
import 'route_names.dart';

abstract final class AppRouter {
  /// ROUTE_MAP의 화면 계약을 테스트하기 위한 정적 path/template 목록이다.
  static const productRoutes = <String>[
    RouteNames.entry,
    RouteNames.profileSetup,
    RouteNames.wifeProfile,
    RouteNames.partnerInvite,
    RouteNames.wifeInvite,
    RouteNames.partnerJoin,
    RouteNames.condition,
    RouteNames.activity,
    RouteNames.wifeHome,
    RouteNames.mealGuide,
    RouteNames.householdGuide,
    RouteNames.wifeMovement,
    RouteNames.partnerMovement,
    RouteNames.healthGuide,
    RouteNames.sleepGuide,
    RouteNames.mealChat,
    RouteNames.dailyReportPattern,
    RouteNames.wifeCalendar,
    RouteNames.wifeMenu,
    RouteNames.wifeSettings,
    RouteNames.partnerMorningReportPattern,
    RouteNames.partnerCalendar,
    RouteNames.partnerNotifications,
    RouteNames.partnerRequestPattern,
  ];

  /// 실제 Session Adapter가 준비되면 이 결정에 인증·역할 상태를 주입한다.
  static String resolveLaunchRoute(
    AppLaunchState state, {
    String? invitationToken,
  }) {
    return switch (state) {
      AppLaunchState.wifeNeedsProfile => RouteNames.entry,
      AppLaunchState.wifeReady => RouteNames.wifeHome,
      AppLaunchState.partnerNeedsLink =>
        invitationToken == null
            ? RouteNames.partnerJoin
            : RouteNames.invitation(token: invitationToken),
      AppLaunchState.partnerLinked => RouteNames.partnerCalendar,
    };
  }

  /// URL을 canonical 경로로 정규화하고 date/requestId/token 진입 맥락을 보존한다.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final requestedName = settings.name ?? RouteNames.root;
    final requestedUri =
        Uri.tryParse(requestedName) ?? Uri(path: RouteNames.entry);
    final normalizedUri = requestedUri.path == RouteNames.root
        ? requestedUri.replace(path: RouteNames.entry)
        : requestedUri;
    final screen = _screenFor(normalizedUri);
    final effectiveUri = screen == null
        ? Uri(path: RouteNames.entry)
        : normalizedUri;
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: effectiveUri.toString(),
        arguments: settings.arguments,
      ),
      builder: (_) => screen ?? const EntryScreen(),
    );
  }

  /// Web 직접 URL 진입 시 중간 path를 별도 Route로 쌓지 않고 대상 화면만 복원한다.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    return [onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  static Widget? _screenFor(Uri uri) {
    final path = uri.path;
    if (path == RouteNames.entry) {
      return EntryScreen(invitationToken: uri.queryParameters['token']);
    }
    if (path == RouteNames.profileSetup) {
      return ProfileSetupScreen(mode: ProfileMode.create);
    }
    if (path == RouteNames.wifeProfile) {
      return ProfileSetupScreen(mode: ProfileMode.edit);
    }
    if (path == RouteNames.partnerInvite) {
      return PartnerInviteScreen(entryContext: InviteEntryContext.onboarding);
    }
    if (path == RouteNames.wifeInvite) {
      return PartnerInviteScreen(entryContext: InviteEntryContext.profileMenu);
    }
    if (path == RouteNames.partnerJoin) {
      return InvitationEntryScreen(token: uri.queryParameters['token']);
    }
    if (path == RouteNames.condition) {
      final mode = uri.queryParameters['mode'] == 'edit'
          ? ConditionMode.edit
          : ConditionMode.create;
      return ConditionScreen(mode: mode);
    }
    if (path == RouteNames.activity) return const ActivityScreen();
    if (path == RouteNames.wifeHome) return const WifeHomeScreen();
    if (path == RouteNames.mealGuide) return const MealGuideScreen();
    if (path == RouteNames.householdGuide) return const HouseholdGuideScreen();
    if (path == RouteNames.wifeMovement) {
      return ProductMovementScreen(role: AppUserRole.wife);
    }
    if (path == RouteNames.partnerMovement) {
      return ProductMovementScreen(role: AppUserRole.partner);
    }
    if (path == RouteNames.healthGuide) return const HealthGuideScreen();
    if (path == RouteNames.sleepGuide) return const SleepGuideScreen();
    if (path == RouteNames.mealChat) return const MealChatScreen();
    if (_matchesDetailPath(uri, actor: 'wife', resource: 'report')) {
      return DailyReportScreen(date: _lastSegment(uri));
    }
    if (path == RouteNames.wifeCalendar) return const WifeCalendarScreen();
    if (path == RouteNames.wifeMenu) {
      return WifeMenuScreen(
        returnLocation: uri.queryParameters['returnLocation'],
      );
    }
    if (path == RouteNames.wifeSettings) return const WifeSettingsScreen();
    if (_matchesDetailPath(uri, actor: 'partner', resource: 'report')) {
      return PartnerMorningReportScreen(date: _lastSegment(uri));
    }
    if (path == RouteNames.partnerCalendar) {
      return const PartnerCalendarScreen();
    }
    if (path == RouteNames.partnerNotifications) {
      return const PartnerNotificationsScreen();
    }
    if (_matchesDetailPath(uri, actor: 'partner', resource: 'requests')) {
      return PartnerRequestScreen(requestId: _lastSegment(uri));
    }
    return null;
  }

  static String _lastSegment(Uri uri) {
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  }

  /// 상세 Route는 정확히 `/{actor}/{resource}/{parameter}` 구조일 때만 연다.
  static bool _matchesDetailPath(
    Uri uri, {
    required String actor,
    required String resource,
  }) {
    final segments = uri.pathSegments;
    return segments.length == 3 &&
        segments[0] == actor &&
        segments[1] == resource &&
        segments[2].isNotEmpty;
  }
}
