import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerMorningReportScreen extends ProductSkeletonScreen {
  const PartnerMorningReportScreen({super.key, required String date})
    : super(
        screenId: 'SCR-H-01',
        title: '파트너 아침 리포트',
        description: '$date 날짜에 공유가 허용된 상태를 읽기 전용으로 보여줍니다.',
        shell: SkeletonShell.partner,
        actions: const [
          SkeletonAction('가사 요청 확인', RouteNames.partnerRequestDemo),
        ],
      );
}
