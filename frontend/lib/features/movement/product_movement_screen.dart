import '../../shared/widgets/product_skeleton_screen.dart';

class ProductMovementScreen extends ProductSkeletonScreen {
  const ProductMovementScreen({super.key})
    : super(
        screenId: 'SCR-W-07',
        title: '실시간 모션',
        description: '제품 노출·동의 정책이 확정되기 전이며 기존 모션 데모 구현은 별도로 보존됩니다.',
        shell: SkeletonShell.wife,
        statusLabel: 'DEFERRED · PHASE 2',
      );
}
