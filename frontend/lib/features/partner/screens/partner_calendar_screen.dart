import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerCalendarScreen extends ProductSkeletonScreen {
  const PartnerCalendarScreen({super.key})
    : super(
        screenId: 'SCR-H-02',
        title: '파트너 캘린더',
        description: '공유가 허용된 기록을 날짜별로 확인하는 Partner Shell 루트입니다.',
        showBack: false,
        shell: SkeletonShell.partner,
        actions: const [
          SkeletonAction('아침 리포트', RouteNames.partnerMorningReportToday),
          SkeletonAction('알림', RouteNames.partnerNotifications),
          SkeletonAction('가사 요청', RouteNames.partnerRequestDemo),
          SkeletonAction('파트너 프로필', RouteNames.partnerProfile),
        ],
      );
}
