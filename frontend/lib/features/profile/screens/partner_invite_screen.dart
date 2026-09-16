import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerInviteScreen extends ProductSkeletonScreen {
  const PartnerInviteScreen({super.key})
    : super(
        screenId: 'SCR-W-14',
        title: '배우자 초대',
        description: '초대 공유와 나중에 하기 흐름이 들어갈 화면입니다.',
        actions: const [
          SkeletonAction('홈으로 이동', RouteNames.wifeHome, replace: true),
        ],
      );
}
