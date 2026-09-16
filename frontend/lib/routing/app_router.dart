import 'package:flutter/material.dart';

import '../features/calendar/screens/wife_calendar_screen.dart';
import '../features/condition/screens/activity_screen.dart';
import '../features/condition/screens/condition_screen.dart';
import '../features/health/screens/health_guide_screen.dart';
import '../features/home/screens/wife_home_screen.dart';
import '../features/household/screens/household_guide_screen.dart';
import '../features/meal/screens/meal_chat_screen.dart';
import '../features/meal/screens/meal_guide_screen.dart';
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
import '../shared/widgets/product_skeleton_screen.dart';
import 'route_context.dart';
import 'route_names.dart';

abstract final class AppRouter {
  /// ROUTE_MAP의 화면 계약을 테스트하기 위한 정적 path/template 목록이다.
  static const productRoutes = <String>[
    RouteNames.profileSetup,
    RouteNames.wifeProfile,
    RouteNames.partnerInvite,
    RouteNames.wifeInvite,
    RouteNames.invitationEntry,
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
    RouteNames.wifeSettings,
    RouteNames.partnerMorningReportPattern,
    RouteNames.partnerCalendar,
    RouteNames.partnerNotifications,
    RouteNames.partnerRequestPattern,
  ];

  /// 실제 Session Adapter가 준비되면 이 결정에 인증·역할 상태를 주입한다.
  static String resolveLaunchRoute(AppLaunchState state) {
    return switch (state) {
      AppLaunchState.wifeNeedsProfile => RouteNames.profileSetup,
      AppLaunchState.wifeReady => RouteNames.wifeHome,
      AppLaunchState.partnerLinked => RouteNames.partnerCalendar,
    };
  }

  /// URL 새로고침에서도 date/requestId/token과 진입 맥락을 보존한다.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final requestedName = settings.name ?? RouteNames.root;
    final uri = Uri.tryParse(requestedName) ?? Uri(path: RouteNames.root);
    final screen = _screenFor(uri);
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: requestedName,
        arguments: settings.arguments,
      ),
      builder: (_) => screen,
    );
  }

  /// Web 직접 URL 진입 시 중간 path를 별도 Route로 쌓지 않고 대상 화면만 복원한다.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    return [onGenerateRoute(RouteSettings(name: initialRoute))];
  }

  static Widget _screenFor(Uri uri) {
    final path = uri.path;
    if (path == RouteNames.root || path == RouteNames.profileSetup) {
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
    if (path == RouteNames.invitationEntry) {
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
    if (path.startsWith('/wife/calendar/report/')) {
      return DailyReportScreen(date: _lastSegment(uri));
    }
    if (path == RouteNames.wifeCalendar) return const WifeCalendarScreen();
    if (path == RouteNames.wifeSettings) return const WifeSettingsScreen();
    if (path.startsWith('/partner/report/')) {
      return PartnerMorningReportScreen(date: _lastSegment(uri));
    }
    if (path == RouteNames.partnerCalendar) {
      return const PartnerCalendarScreen();
    }
    if (path == RouteNames.partnerNotifications) {
      return const PartnerNotificationsScreen();
    }
    if (path.startsWith('/partner/requests/')) {
      return PartnerRequestScreen(requestId: _lastSegment(uri));
    }
    return ProductSkeletonScreen(
      requirementIds: const [],
      title: '화면을 찾을 수 없습니다',
      description: '등록되지 않은 경로입니다: $path',
      actions: const [
        SkeletonAction('프로필 시작으로 이동', RouteNames.profileSetup, replace: true),
      ],
    );
  }

  static String _lastSegment(Uri uri) {
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  }
}
