import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class ConditionScreen extends ProductSkeletonScreen {
  const ConditionScreen({super.key, required ConditionMode mode})
    : super(
        screenId: 'SCR-W-02',
        title: '오늘의 컨디션',
        description: mode == ConditionMode.create
            ? '통증·피로도 등 오늘 상태를 입력할 화면입니다.'
            : '저장된 오늘 상태를 불러와 수정하는 화면입니다.',
        shell: SkeletonShell.wife,
        actions: mode == ConditionMode.create
            ? const [SkeletonAction('다음: 예정 활동', RouteNames.activity)]
            : const [
                SkeletonAction('수정 저장 후 홈', RouteNames.wifeHome, replace: true),
              ],
      );
}
