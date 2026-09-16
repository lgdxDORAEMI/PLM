import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class HouseholdGuideScreen extends ProductSkeletonScreen {
  const HouseholdGuideScreen({super.key})
    : super(
        requirementIds: const [
          'W-HOUSE-001',
          'W-HOUSE-002',
          'W-HOUSE-003',
          'W-RECORD-002',
        ],
        title: '가사 가이드',
        description: '직접 수행·가전 추천·가족 분담을 구분할 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('요청 전송 후 홈', RouteNames.wifeHome, replace: true),
        ],
      );
}
