import '../../routing/route_context.dart';
import '../../shared/widgets/product_skeleton_screen.dart';

class ProductMovementScreen extends ProductSkeletonScreen {
  const ProductMovementScreen({super.key, required AppUserRole role})
    : super(
        screenId: 'SCR-W-07',
        title: '실시간 모션',
        description:
            '${role == AppUserRole.wife ? "아내" : "파트너"}가 공유 위험 행동 로그를 조회할 Phase 2 화면입니다. 기존 모션 데모는 별도로 보존됩니다.',
        shell: role == AppUserRole.wife
            ? SkeletonShell.wife
            : SkeletonShell.partner,
        statusLabel: 'DEFERRED · PHASE 2',
      );
}
