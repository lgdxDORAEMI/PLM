import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class MealChatScreen extends ProductSkeletonScreen {
  const MealChatScreen({super.key})
    : super(
        screenId: 'SCR-W-10',
        title: '식사 재조정 채팅',
        description: '선택한 식사 맥락 안에서 대체 식사를 고르는 화면입니다.',
        actions: const [
          SkeletonAction('대체 식사 적용', RouteNames.mealGuide, replace: true),
        ],
      );
}
