import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerProfileScreen extends ProductSkeletonScreen {
  const PartnerProfileScreen({super.key})
    : super(
        screenId: 'SCR-H-05',
        title: '파트너 프로필',
        description: '연결된 사용자 정보를 읽기 전용으로 확인할 화면입니다.',
      );
}
