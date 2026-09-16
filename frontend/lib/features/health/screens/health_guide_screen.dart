import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class HealthGuideScreen extends ProductSkeletonScreen {
  const HealthGuideScreen({super.key})
    : super(
        screenId: 'SCR-W-08',
        title: '건강 가이드',
        description: '컨디션 기반의 행동 중심 건강 가이드가 들어갈 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('완료 후 홈', RouteNames.wifeHome, replace: true),
        ],
      );
}
