import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class ProfileSetupScreen extends ProductSkeletonScreen {
  const ProfileSetupScreen({super.key, required ProfileMode mode})
    : super(
        screenId: 'SCR-W-01',
        title: mode == ProfileMode.create ? '임산부 프로필 설정' : '임산부 프로필 수정',
        description: mode == ProfileMode.create
            ? '최초 등록용 6단계 프로필 Wizard가 들어갈 화면입니다.'
            : '기존 프로필을 수정하고 진입 지점으로 복귀하는 화면입니다.',
        showBack: mode == ProfileMode.edit,
        actions: mode == ProfileMode.create
            ? const [SkeletonAction('프로필 입력 완료', RouteNames.partnerInvite)]
            : const [
                SkeletonAction('수정 저장 후 이전 화면', RouteNames.wifeHome, pop: true),
              ],
      );
}
