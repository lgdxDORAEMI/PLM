import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class ActivityScreen extends ProductSkeletonScreen {
  const ActivityScreen({super.key})
    : super(
        requirementIds: const ['W-ACT-001'],
        title: '오늘 예정 활동',
        description: '오늘 수행할 활동을 복수 선택하는 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('루틴 생성 후 홈', RouteNames.wifeHome, replace: true),
        ],
      );
}
