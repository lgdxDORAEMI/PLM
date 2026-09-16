/// 중앙에서 관리하는 내부 제품 경로다.
///
/// 외부 deep link/API 계약이 아니라 ROUTE_MAP 후보를 Skeleton 검증에 사용한다.
abstract final class RouteNames {
  static const root = '/';
  static const profileSetup = '/onboarding/profile';
  static const partnerInvite = '/onboarding/invite';
  static const invitationEntry = '/invitation-entry';
  static const condition = '/wife/home/condition';
  static const activity = '/wife/home/activity';
  static const wifeHome = '/wife/home';
  static const mealGuide = '/wife/home/meal';
  static const householdGuide = '/wife/home/household';
  static const movement = '/wife/movement';
  static const healthGuide = '/wife/home/health';
  static const sleepGuide = '/wife/home/sleep';
  static const mealChat = '/wife/meal-chat';
  static const dailyReport = '/wife/calendar/report/today';
  static const wifeCalendar = '/wife/calendar';
  static const wifeSettings = '/wife/settings';
  static const partnerMorningReport = '/partner/report/today';
  static const partnerCalendar = '/partner/calendar';
  static const partnerNotifications = '/partner/notifications';
  static const partnerRequest = '/partner/requests/demo-request';
  static const partnerProfile = '/partner/profile';
}
