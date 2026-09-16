import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class InvitationEntryScreen extends ProductSkeletonScreen {
  const InvitationEntryScreen({super.key})
    : super(
        screenId: 'SCR-H-06',
        title: '초대 수락',
        description: '외부 초대 Context의 유효 상태를 확인하고 연결할 화면입니다.',
        showBack: false,
        actions: const [
          SkeletonAction('연결 완료', RouteNames.partnerCalendar, replace: true),
        ],
      );
}
