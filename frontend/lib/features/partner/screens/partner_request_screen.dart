import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerRequestScreen extends ProductSkeletonScreen {
  const PartnerRequestScreen({super.key, required String requestId})
    : super(
        screenId: 'SCR-H-04',
        title: '파트너 가사 요청',
        description: '$requestId 요청의 확인·완료 상태 전이가 들어갈 상세 화면입니다.',
        shell: SkeletonShell.partner,
      );
}
