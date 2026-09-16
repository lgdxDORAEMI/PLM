import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class MealChatScreen extends ProductSkeletonScreen {
  const MealChatScreen({super.key})
    : super(
        requirementIds: const ['W-MEAL-002', 'W-CHAT-001', 'W-CHAT-002'],
        title: '식사 재조정 채팅',
        description: '선택한 식사 맥락 안에서 대체 식사를 고르는 화면입니다.',
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('대체 식사 적용', RouteNames.mealGuide, replace: true),
        ],
      );
}
