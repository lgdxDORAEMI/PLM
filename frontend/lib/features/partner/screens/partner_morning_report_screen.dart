import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerMorningReportScreen extends ProductSkeletonScreen {
  const PartnerMorningReportScreen({super.key})
    : super(
        screenId: 'SCR-H-01',
        title: '파트너 아침 리포트',
        description: '배우자가 공유를 허용한 오늘 상태를 읽기 전용으로 보여줍니다.',
        actions: const [SkeletonAction('가사 요청 확인', RouteNames.partnerRequest)],
      );
}
