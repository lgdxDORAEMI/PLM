import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class ConditionScreen extends ProductSkeletonScreen {
  const ConditionScreen({super.key})
    : super(
        screenId: 'SCR-W-02',
        title: '오늘의 컨디션',
        description: '통증·피로도 등 오늘 상태를 입력할 화면입니다.',
        actions: const [SkeletonAction('다음: 예정 활동', RouteNames.activity)],
      );
}
