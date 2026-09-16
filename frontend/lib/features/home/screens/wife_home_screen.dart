import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class WifeHomeScreen extends ProductSkeletonScreen {
  const WifeHomeScreen({super.key})
    : super(
        screenId: 'SCR-W-04',
        title: '통합 홈',
        description: '임신 주차와 오늘의 케어 진입점을 제공할 Wife Shell의 루트입니다.',
        showBack: false,
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('오늘 컨디션 입력', RouteNames.condition),
          SkeletonAction('식사 가이드', RouteNames.mealGuide),
          SkeletonAction('가사 가이드', RouteNames.householdGuide),
          SkeletonAction('건강 가이드', RouteNames.healthGuide),
          SkeletonAction('수면 가이드', RouteNames.sleepGuide),
          SkeletonAction('하루 루틴 끝내기', RouteNames.dailyReport),
          SkeletonAction('프로필 수정', RouteNames.profileSetup),
          SkeletonAction('설정 (Phase 2)', RouteNames.wifeSettings),
        ],
      );
}
