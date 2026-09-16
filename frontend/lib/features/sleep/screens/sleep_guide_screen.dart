import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class SleepGuideScreen extends ProductSkeletonScreen {
  const SleepGuideScreen({super.key})
    : super(
        requirementIds: const ['W-SLEEP-001', 'W-SLEEP-002', 'W-RECORD-001'],
        title: '수면 가이드',
        description: '수면 환경과 오늘의 루틴을 선택할 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('완료 후 홈', RouteNames.wifeHome, replace: true),
        ],
      );
}
