import 'package:flutter/material.dart';

import '../features/calendar/screens/wife_calendar_screen.dart';
import '../features/condition/screens/activity_screen.dart';
import '../features/condition/screens/condition_screen.dart';
import '../features/health/screens/health_guide_screen.dart';
import '../features/home/screens/wife_home_screen.dart';
import '../features/household/screens/household_guide_screen.dart';
import '../features/meal/screens/meal_chat_screen.dart';
import '../features/meal/screens/meal_guide_screen.dart';
import '../features/meal/models/meal_guide.dart';
import '../features/menu/screens/wife_menu_screen.dart';
import '../features/movement/product_movement_screen.dart';
import '../features/partner/screens/invitation_entry_screen.dart';
import '../features/partner/screens/partner_calendar_screen.dart';
import '../features/partner/screens/partner_morning_report_screen.dart';
import '../features/partner/screens/partner_notifications_screen.dart';
import '../features/partner/screens/partner_request_screen.dart';
import '../features/partner/screens/partner_request_result_screen.dart';
import '../features/profile/data/profile_store.dart';
import '../features/profile/screens/partner_invite_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import '../features/report/screens/daily_report_screen.dart';
import '../features/routine/screens/routine_fallback_screen.dart';
import '../features/settings/screens/wife_settings_screen.dart';
import '../features/sleep/screens/sleep_guide_screen.dart';
import 'app_session.dart';
import 'route_context.dart';
import 'route_names.dart';

final class _RoleSwitchIntent {
  const _RoleSwitchIntent();
}

abstract final class AppRouter {
  static const productRoutes = <String>[
    RouteNames.entry,
    RouteNames.inviteAccept,
    RouteNames.roleSwitchPattern,
    RouteNames.wifeHome,
    RouteNames.wifeMovement,
    RouteNames.mealChat,
    RouteNames.wifeCalendar,
    RouteNames.profileOnboardingPattern,
    RouteNames.profileEditPattern,
    RouteNames.wifeInvite,
    RouteNames.wifeMenu,
    RouteNames.condition,
    RouteNames.activity,
    RouteNames.routineFallback,
    RouteNames.mealGuide,
    RouteNames.mealDetailPattern,
    RouteNames.householdGuide,
    RouteNames.healthGuide,
    RouteNames.sleepGuide,
    RouteNames.dailyReportPattern,
    RouteNames.husbandCalendar,
    RouteNames.husbandMovement,
    RouteNames.husbandNotifications,
    RouteNames.husbandMorningReportPattern,
    RouteNames.husbandDailyReportPattern,
    RouteNames.husbandRequestPattern,
    RouteNames.husbandRequestResultPattern,
  ];

  /// 역할 전환은 내부 명령으로만 호출하며 이전 역할 stack을 전부 제거한다.
  static bool switchRole(BuildContext context, ActiveRole targetRole) {
    final auth = AuthSessionStore.instance;
    if (!auth.canAccess(targetRole)) return false;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.roleSwitch(targetRole.name),
      (_) => false,
      arguments: const _RoleSwitchIntent(),
    );
    return true;
  }

  /// ThinQ/시연 세션의 최초 목적지를 계산한다.
  static String resolveLaunchRoute(
    AppLaunchState state, {
    String? invitationToken,
  }) => switch (state) {
    AppLaunchState.wifeNeedsProfile => RouteNames.profileSetup,
    AppLaunchState.wifeReady => RouteNames.wifeHome,
    AppLaunchState.partnerNeedsLink =>
      invitationToken == null
          ? RouteNames.entry
          : RouteNames.invitation(token: invitationToken),
    AppLaunchState.partnerLinked => RouteNames.husbandCalendar,
  };

  /// 새로고침/직접 URL을 같은 guard로 정규화한다. URL만으로 역할을 바꾸지 않는다.
  static String resolveLocation(String requestedName) {
    final uri = Uri.tryParse(requestedName);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return RouteNames.entry;
    }
    final path = uri.path == RouteNames.root ? RouteNames.entry : uri.path;
    final auth = AuthSessionStore.instance;
    final roles = ActiveRoleStore.instance;
    if (!auth.isAuthenticated) return RouteNames.entry;
    if (path == RouteNames.inviteAccept) return uri.toString();
    if (roles.value == null) roles.restoreFor(auth);
    final active = roles.value;
    if (active == null) return RouteNames.entry;
    if (active == ActiveRole.husband && !auth.canAccess(active)) {
      return RouteNames.entry;
    }
    if (!auth.canAccess(active)) return RouteNames.entry;
    if (path == RouteNames.entry) return _homeFor(active);
    if (path.startsWith('/role/switch/')) return _homeFor(active);
    if (!_isKnownPath(path)) return _homeFor(active);

    final requestedRole = path.startsWith('/wife/')
        ? ActiveRole.wife
        : path.startsWith('/husband/')
        ? ActiveRole.husband
        : null;
    if (requestedRole != active) return _homeFor(active);
    if (active == ActiveRole.wife && !ProfileStore.instance.hasProfile) {
      return RouteNames.profileSetup;
    }
    if (path.startsWith('/wife/profile/onboarding/') &&
        !ProfileStore.instance.hasProfile) {
      return RouteNames.profileSetup;
    }
    if (path == RouteNames.wifeInvite && auth.husbandLinked) {
      return RouteNames.wifeHome;
    }
    if (path.startsWith('/wife/profile/onboarding/') &&
        ProfileStore.instance.hasProfile) {
      return RouteNames.wifeHome;
    }
    if (path.startsWith('/wife/profile/edit/') &&
        !ProfileStore.instance.hasProfile) {
      return RouteNames.profileSetup;
    }
    return uri.toString();
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final requested = settings.name ?? RouteNames.root;
    final requestedUri = Uri.tryParse(requested);
    final segments = requestedUri?.pathSegments ?? const <String>[];
    if (segments.length == 3 &&
        segments[0] == 'role' &&
        segments[1] == 'switch' &&
        settings.arguments is _RoleSwitchIntent) {
      final target = switch (segments[2]) {
        'wife' => ActiveRole.wife,
        'husband' => ActiveRole.husband,
        _ => null,
      };
      if (target != null) {
        ActiveRoleStore.instance.switchTo(target, AuthSessionStore.instance);
      }
      final role = ActiveRoleStore.instance.value;
      final destination = role == null ? RouteNames.entry : _homeFor(role);
      return _page(destination, _screenFor(Uri(path: destination)));
    }

    final location = resolveLocation(requested);
    final uri = Uri.parse(location);
    return _page(location, _screenFor(uri));
  }

  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) => [
    onGenerateRoute(RouteSettings(name: initialRoute)),
  ];

  static Route<dynamic> _page(String name, Widget screen) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => screen,
      );

  static String _homeFor(ActiveRole role) => role == ActiveRole.husband
      ? RouteNames.husbandCalendar
      : ProfileStore.instance.hasProfile
      ? RouteNames.wifeHome
      : RouteNames.profileSetup;

  static bool _isKnownPath(String path) {
    if (_wifePages.contains(path) || _husbandPages.contains(path)) return true;
    final parts = Uri.parse(path).pathSegments;
    if (parts.length == 4 &&
        parts[0] == 'wife' &&
        parts[1] == 'profile' &&
        (parts[2] == 'onboarding' || parts[2] == 'edit')) {
      final step = int.tryParse(parts[3]);
      return parts[3] == 'summary' || (step != null && step >= 1 && step <= 6);
    }
    if (parts.length == 3 && parts[0] == 'wife') {
      if (parts[1] == 'report') return _validDate(parts[2]);
      if (parts[1] == 'meal') return parts[2].isNotEmpty;
    }
    if (parts.length == 4 && parts[0] == 'husband') {
      if (parts[1] == 'report' &&
          (parts[2] == 'morning' || parts[2] == 'daily')) {
        return _validDate(parts[3]);
      }
    }
    if (parts.length == 3 && parts[0] == 'husband' && parts[1] == 'requests') {
      return parts[2].isNotEmpty;
    }
    return parts.length == 4 &&
        parts[0] == 'husband' &&
        parts[1] == 'requests' &&
        parts[2].isNotEmpty &&
        parts[3] == 'result';
  }

  static bool _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final date = DateTime.tryParse(value);
    return date != null &&
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' ==
            value;
  }

  static const _wifePages = <String>{
    RouteNames.wifeHome,
    RouteNames.wifeMovement,
    RouteNames.mealChat,
    RouteNames.wifeCalendar,
    RouteNames.wifeInvite,
    RouteNames.wifeMenu,
    RouteNames.condition,
    RouteNames.activity,
    RouteNames.routineFallback,
    RouteNames.mealGuide,
    RouteNames.householdGuide,
    RouteNames.healthGuide,
    RouteNames.sleepGuide,
    RouteNames.wifeSettings,
  };
  static const _husbandPages = <String>{
    RouteNames.husbandCalendar,
    RouteNames.husbandMovement,
    RouteNames.husbandNotifications,
  };

  static Widget _screenFor(Uri uri) {
    final path = uri.path;
    final parts = uri.pathSegments;
    if (path == RouteNames.entry) {
      final auth = AuthSessionStore.instance;
      final needsInvite =
          auth.isAuthenticated &&
          ActiveRoleStore.instance.value == ActiveRole.husband &&
          !auth.husbandLinked;
      return _RoutePlaceholder(
        title: needsInvite ? '초대가 필요합니다' : 'ThinQ에서 사용자 상태를 확인해 주세요',
      );
    }
    if (path == RouteNames.inviteAccept) {
      return InvitationEntryScreen(token: uri.queryParameters['token']);
    }
    if (parts.length == 4 && parts[0] == 'wife' && parts[1] == 'profile') {
      final isEdit = parts[2] == 'edit';
      final step = parts[3] == 'summary' ? 6 : int.parse(parts[3]) - 1;
      return ProfileSetupScreen(
        mode: isEdit ? ProfileMode.edit : ProfileMode.create,
        initialStep: step,
        returnToSummary: isEdit && step < 6,
      );
    }
    if (path == RouteNames.wifeInvite) {
      return PartnerInviteScreen(
        entryContext: uri.queryParameters['source'] == 'onboarding'
            ? InviteEntryContext.onboarding
            : InviteEntryContext.profileMenu,
      );
    }
    if (path == RouteNames.condition) {
      return ConditionScreen(
        mode: uri.queryParameters['mode'] == 'edit'
            ? ConditionMode.edit
            : ConditionMode.create,
      );
    }
    if (path == RouteNames.activity) return const ActivityScreen();
    if (path == RouteNames.wifeHome) return const WifeHomeScreen();
    if (path == RouteNames.mealGuide) return const MealGuideScreen();
    if (parts.length == 3 && parts[0] == 'wife' && parts[1] == 'meal') {
      return const _RoutePlaceholder(title: '식사 상세 화면 준비 중');
    }
    if (path == RouteNames.householdGuide) return const HouseholdGuideScreen();
    if (path == RouteNames.wifeMovement) {
      return const ProductMovementScreen(role: AppUserRole.wife);
    }
    if (path == RouteNames.husbandMovement) {
      return const ProductMovementScreen(role: AppUserRole.husband);
    }
    if (path == RouteNames.healthGuide) return const HealthGuideScreen();
    if (path == RouteNames.sleepGuide) return const SleepGuideScreen();
    if (path == RouteNames.mealChat) {
      final period = MealPeriod.values
          .where((item) => item.name == uri.queryParameters['period'])
          .firstOrNull;
      return MealChatScreen(mealPeriod: period);
    }
    if (parts.length == 3 && parts[0] == 'wife' && parts[1] == 'report') {
      return DailyReportScreen(date: parts[2]);
    }
    if (path == RouteNames.wifeCalendar) return const WifeCalendarScreen();
    if (path == RouteNames.wifeMenu) {
      return WifeMenuScreen(
        returnLocation: uri.queryParameters['returnLocation'],
      );
    }
    if (path == RouteNames.wifeSettings) return const WifeSettingsScreen();
    if (path == RouteNames.husbandCalendar) {
      return const PartnerCalendarScreen();
    }
    if (path == RouteNames.husbandNotifications) {
      return const PartnerNotificationsScreen();
    }
    if (parts.length == 4 && parts[0] == 'husband' && parts[1] == 'report') {
      if (parts[2] == 'morning') {
        return PartnerMorningReportScreen(date: parts[3]);
      }
      return PartnerMorningReportScreen(date: parts[3], daily: true);
    }
    if (parts.length >= 3 && parts[0] == 'husband' && parts[1] == 'requests') {
      if (parts.length == 4) {
        return PartnerRequestResultScreen(requestId: parts[2]);
      }
      return PartnerRequestScreen(requestId: parts[2]);
    }
    if (path == RouteNames.routineFallback) {
      return const RoutineFallbackScreen();
    }
    return const _RoutePlaceholder(title: '화면을 준비 중입니다');
  }
}

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PLM')),
    body: Center(child: Text(title)),
  );
}
