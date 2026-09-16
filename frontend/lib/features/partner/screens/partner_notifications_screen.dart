import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerNotificationsScreen extends ProductSkeletonScreen {
  const PartnerNotificationsScreen({super.key})
    : super(
        screenId: 'SCR-H-03',
        title: '알림',
        description: 'MVP의 앱 내 Mock 알림함이 들어갈 화면입니다.',
        shell: SkeletonShell.partner,
        actions: const [
          SkeletonAction('리포트 알림 열기', RouteNames.partnerMorningReportToday),
          SkeletonAction('요청 알림 열기', RouteNames.partnerRequestDemo),
        ],
      );
}
