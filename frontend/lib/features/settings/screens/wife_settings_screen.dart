import '../../../shared/widgets/product_skeleton_screen.dart';

class WifeSettingsScreen extends ProductSkeletonScreen {
  const WifeSettingsScreen({super.key})
    : super(
        screenId: 'SCR-W-13',
        title: '설정',
        description: '상세 요구사항이 확정될 때까지 임의 설정 항목을 만들지 않습니다.',
        statusLabel: 'BLOCKED · PHASE 2',
      );
}
