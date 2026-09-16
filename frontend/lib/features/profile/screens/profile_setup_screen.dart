import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class ProfileSetupScreen extends ProductSkeletonScreen {
  const ProfileSetupScreen({super.key})
    : super(
        screenId: 'SCR-W-01',
        title: '임산부 프로필 설정',
        description: '6단계 프로필 Wizard가 들어갈 화면입니다.',
        showBack: false,
        actions: const [SkeletonAction('프로필 입력 완료', RouteNames.partnerInvite)],
      );
}
