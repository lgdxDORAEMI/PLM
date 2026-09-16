import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class HouseholdGuideScreen extends ProductSkeletonScreen {
  const HouseholdGuideScreen({super.key})
    : super(
        screenId: 'SCR-W-06',
        title: '가사 가이드',
        description: '직접 수행·가전 추천·가족 분담을 구분할 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('파트너 요청 상태 보기', RouteNames.partnerRequest),
        ],
      );
}
