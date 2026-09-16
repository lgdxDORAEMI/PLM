/// 서비스 흐름도와 ROUTE_MAP을 반영한 내부 제품 경로다.
/// 외부 Deep Link domain과 인증 복귀 URL은 별도 계약 전까지 확정하지 않는다.
abstract final class RouteNames {
  static const root = '/';
  static const profileSetup = '/onboarding/profile';
  static const wifeProfile = '/wife/profile';
  static const partnerInvite = '/onboarding/invite';
  static const wifeInvite = '/wife/invite';
  static const invitationEntry = '/invitation-entry';
  static const condition = '/wife/home/condition';
  static const activity = '/wife/home/activity';
  static const wifeHome = '/wife/home';
  static const mealGuide = '/wife/home/meal';
  static const householdGuide = '/wife/home/household';
  static const wifeMovement = '/wife/movement';
  static const partnerMovement = '/partner/movement';
  static const healthGuide = '/wife/home/health';
  static const sleepGuide = '/wife/home/sleep';
  static const mealChat = '/wife/meal-chat';
  static const dailyReportPattern = '/wife/calendar/report/:date';
  static const dailyReportToday = '/wife/calendar/report/today';
  static const wifeCalendar = '/wife/calendar';
  static const wifeSettings = '/wife/settings';
  static const partnerMorningReportPattern = '/partner/report/:date';
  static const partnerMorningReportToday = '/partner/report/today';
  static const partnerCalendar = '/partner/calendar';
  static const partnerNotifications = '/partner/notifications';
  static const partnerProfile = '/partner/profile';
  static const partnerRequestPattern = '/partner/requests/:requestId';
  static const partnerRequestDemo = '/partner/requests/demo-request';

  static String dailyReport(String date) =>
      '/wife/calendar/report/${Uri.encodeComponent(date)}';

  static String partnerMorningReport(String date) =>
      '/partner/report/${Uri.encodeComponent(date)}';

  static String partnerRequest(String requestId) =>
      '/partner/requests/${Uri.encodeComponent(requestId)}';

  static String invitation({required String token}) {
    return Uri(
      path: invitationEntry,
      queryParameters: {'token': token},
    ).toString();
  }
}
