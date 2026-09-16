/// 서비스 흐름도와 ROUTE_MAP을 반영한 내부 제품 경로다.
/// 외부 Deep Link domain과 인증 복귀 URL은 별도 계약 전까지 확정하지 않는다.
abstract final class RouteNames {
  static const root = '/';
  static const entry = '/entry';
  static const profileSetup = '/onboarding/profile';
  static const wifeProfile = '/wife/profile';
  static const partnerInvite = '/onboarding/invite';
  static const wifeInvite = '/wife/invite';
  static const partnerJoin = '/partner/join';
  static const condition = '/wife/condition';
  static const activity = '/wife/activity';
  static const wifeHome = '/wife/home';
  static const mealGuide = '/wife/meal';
  static const householdGuide = '/wife/household';
  static const wifeMovement = '/wife/movement';
  static const partnerMovement = '/partner/movement';
  static const healthGuide = '/wife/health';
  static const sleepGuide = '/wife/sleep';
  static const mealChat = '/wife/chat';
  static const dailyReportPattern = '/wife/report/:date';
  static const wifeCalendar = '/wife/calendar';
  static const wifeMenu = '/wife/menu';
  static const wifeSettings = '/wife/settings';
  static const partnerMorningReportPattern = '/partner/report/:date';
  static const partnerCalendar = '/partner/calendar';
  static const partnerNotifications = '/partner/notifications';
  static const partnerRequestPattern = '/partner/requests/:requestId';

  static String dailyReport(String date) =>
      '/wife/report/${Uri.encodeComponent(date)}';

  static String partnerMorningReport(String date) =>
      '/partner/report/${Uri.encodeComponent(date)}';

  static String partnerRequest(String requestId) =>
      '/partner/requests/${Uri.encodeComponent(requestId)}';

  static String invitation({required String token}) {
    return Uri(path: partnerJoin, queryParameters: {'token': token}).toString();
  }

  static String menu({String? returnLocation}) => Uri(
    path: wifeMenu,
    queryParameters: returnLocation == null
        ? null
        : {'returnLocation': returnLocation},
  ).toString();
}
