import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerCalendarScreen extends ProductSkeletonScreen {
  const PartnerCalendarScreen({super.key})
    : super(
        screenId: 'SCR-H-02',
        title: '파트너 캘린더',
        description: '공유가 허용된 기록을 날짜별로 확인하는 Partner Shell 루트입니다.',
        showBack: false,
        // Partner bottom navigation IA는 아직 확정되지 않아 Skeleton에서 고정하지 않는다.
        shell: SkeletonShell.none,
        actions: const [
          SkeletonAction('아침 리포트', RouteNames.partnerMorningReport),
          SkeletonAction('알림', RouteNames.partnerNotifications),
          SkeletonAction('가사 요청', RouteNames.partnerRequest),
          SkeletonAction('파트너 프로필', RouteNames.partnerProfile),
        ],
      );
}
