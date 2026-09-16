import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class MealGuideScreen extends ProductSkeletonScreen {
  const MealGuideScreen({super.key})
    : super(
        requirementIds: const [
          'W-MEAL-001',
          'W-MEAL-002',
          'W-MEAL-003',
          'W-MEAL-004',
          'W-RECORD-001',
        ],
        title: '식사 가이드',
        description: '오늘의 식사 추천과 추천 근거가 들어갈 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('추천 수락 후 홈', RouteNames.wifeHome, replace: true),
          SkeletonAction('식사 다시 추천받기', RouteNames.mealChat),
        ],
      );
}
