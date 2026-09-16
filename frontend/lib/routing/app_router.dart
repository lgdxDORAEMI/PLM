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
import '../features/partner/screens/partner_profile_screen.dart';
import '../features/partner/screens/partner_request_screen.dart';
import '../features/profile/screens/partner_invite_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import '../features/report/screens/daily_report_screen.dart';
import '../features/settings/screens/wife_settings_screen.dart';
import '../features/sleep/screens/sleep_guide_screen.dart';
import '../shared/widgets/product_skeleton_screen.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static const productRoutes = <String>[
    RouteNames.profileSetup,
    RouteNames.partnerInvite,
    RouteNames.invitationEntry,
    RouteNames.condition,
    RouteNames.activity,
    RouteNames.wifeHome,
    RouteNames.mealGuide,
    RouteNames.householdGuide,
    RouteNames.movement,
    RouteNames.healthGuide,
    RouteNames.sleepGuide,
    RouteNames.mealChat,
    RouteNames.dailyReport,
    RouteNames.wifeCalendar,
    RouteNames.wifeSettings,
    RouteNames.partnerMorningReport,
    RouteNames.partnerCalendar,
    RouteNames.partnerNotifications,
    RouteNames.partnerRequest,
    RouteNames.partnerProfile,
  ];

  /// URL 새로고침도 동일한 화면으로 복원되도록 path를 중앙에서 해석한다.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final requestedName = settings.name ?? RouteNames.root;
    final uri = Uri.tryParse(requestedName);
    final path = uri?.path ?? RouteNames.root;
    final canonicalPath = _canonicalize(path);
    final screen = _screenFor(canonicalPath);
    return MaterialPageRoute<void>(
      settings: RouteSettings(
        name: canonicalPath,
        arguments: settings.arguments,
      ),
      builder: (_) => screen,
    );
  }

  static String _canonicalize(String path) {
    if (path == RouteNames.root) return RouteNames.profileSetup;
    if (path.startsWith('/wife/calendar/report/')) {
      return RouteNames.dailyReport;
    }
    if (path.startsWith('/partner/report/')) {
      return RouteNames.partnerMorningReport;
    }
    if (path.startsWith('/partner/requests/')) return RouteNames.partnerRequest;
    return path;
  }

  static Widget _screenFor(String path) {
    return switch (path) {
      RouteNames.profileSetup => const ProfileSetupScreen(),
      RouteNames.partnerInvite => const PartnerInviteScreen(),
      RouteNames.invitationEntry => const InvitationEntryScreen(),
      RouteNames.condition => const ConditionScreen(),
      RouteNames.activity => const ActivityScreen(),
      RouteNames.wifeHome => const WifeHomeScreen(),
      RouteNames.mealGuide => const MealGuideScreen(),
      RouteNames.householdGuide => const HouseholdGuideScreen(),
      RouteNames.movement => const ProductMovementScreen(),
      RouteNames.healthGuide => const HealthGuideScreen(),
      RouteNames.sleepGuide => const SleepGuideScreen(),
      RouteNames.mealChat => const MealChatScreen(),
      RouteNames.dailyReport => const DailyReportScreen(),
      RouteNames.wifeCalendar => const WifeCalendarScreen(),
      RouteNames.wifeSettings => const WifeSettingsScreen(),
      RouteNames.partnerMorningReport => const PartnerMorningReportScreen(),
      RouteNames.partnerCalendar => const PartnerCalendarScreen(),
      RouteNames.partnerNotifications => const PartnerNotificationsScreen(),
      RouteNames.partnerRequest => const PartnerRequestScreen(),
      RouteNames.partnerProfile => const PartnerProfileScreen(),
      _ => ProductSkeletonScreen(
        screenId: '404',
        title: '화면을 찾을 수 없습니다',
        description: '등록되지 않은 경로입니다: $path',
        actions: const [
          SkeletonAction('프로필 시작으로 이동', RouteNames.profileSetup, replace: true),
        ],
      ),
    };
  }
}
