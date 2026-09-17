/// PLM V2 경로. 기존 화면 클래스명은 점진적으로 정리한다.
abstract final class RouteNames {
  static const root = '/';
  static const entry = '/entry';
  static const inviteAccept = '/invite/accept';
  static const roleSwitchPattern = '/role/switch/:targetRole';

  static const wifeHome = '/wife/home';
  static const wifeMovement = '/wife/live';
  static const mealChat = '/wife/chat';
  static const wifeCalendar = '/wife/calendar';
  static const profileSetup = '/wife/profile/onboarding/1';
  static const wifeProfile = '/wife/profile/edit/summary';
  static const profileOnboardingPattern = '/wife/profile/onboarding/:step';
  static const profileEditPattern = '/wife/profile/edit/:step';
  static const wifeInvite = '/wife/invite';
  static const condition = '/wife/condition';
  static const activity = '/wife/tasks';
  static const routineFallback = '/wife/routine/fallback';
  static const mealGuide = '/wife/meal';
  static const mealDetailPattern = '/wife/meal/:mealKey';
  static const householdGuide = '/wife/house';
  static const healthGuide = '/wife/health';
  static const sleepGuide = '/wife/sleep';
  static const dailyReportPattern = '/wife/report/:date';
  static const wifeMenu = '/wife/menu';
  static const wifeSettings = '/wife/settings';

  static const husbandCalendar = '/husband/calendar';
  static const husbandMovement = '/husband/live';
  static const husbandNotifications = '/husband/notifications';
  static const husbandMorningReportPattern = '/husband/report/morning/:date';
  static const husbandDailyReportPattern = '/husband/report/daily/:date';
  static const husbandRequestPattern = '/husband/requests/:requestId';
  static const husbandRequestResultPattern =
      '/husband/requests/:requestId/result';

  // 기존 화면의 호출 지점을 유지하는 별칭. URL은 V2 경로만 생성한다.
  static const partnerInvite = '/wife/invite?source=onboarding';
  static const partnerJoin = inviteAccept;
  static const partnerMovement = husbandMovement;
  static const partnerCalendar = husbandCalendar;
  static const partnerNotifications = husbandNotifications;
  static const partnerMorningReportPattern = husbandMorningReportPattern;
  static const partnerRequestPattern = husbandRequestPattern;

  static String dailyReport(String date) =>
      '/wife/report/${Uri.encodeComponent(date)}';
  static String husbandMorningReport(String date) =>
      '/husband/report/morning/${Uri.encodeComponent(date)}';
  static String husbandDailyReport(String date) =>
      '/husband/report/daily/${Uri.encodeComponent(date)}';
  static String husbandRequest(String id) =>
      '/husband/requests/${Uri.encodeComponent(id)}';
  static String husbandRequestResult(String id) =>
      '${husbandRequest(id)}/result';
  static String mealDetail(String mealKey) =>
      '/wife/meal/${Uri.encodeComponent(mealKey)}';
  static String roleSwitch(String targetRole) =>
      '/role/switch/${Uri.encodeComponent(targetRole)}';

  static String partnerMorningReport(String date) => husbandMorningReport(date);
  static String partnerRequest(String requestId) => husbandRequest(requestId);
  static String invitation({required String token}) =>
      Uri(path: inviteAccept, queryParameters: {'token': token}).toString();
  static String menu({String? returnLocation}) => Uri(
    path: wifeMenu,
    queryParameters: returnLocation == null
        ? null
        : {'returnLocation': returnLocation},
  ).toString();
}
