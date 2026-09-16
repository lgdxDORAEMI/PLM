import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class InvitationEntryScreen extends ProductSkeletonScreen {
  InvitationEntryScreen({super.key, required String? token})
    : super(
        screenId: 'SCR-H-06',
        title: '초대 수락',
        description: token == null || token.isEmpty
            ? '초대 토큰이 없어 만료·잘못된 링크 안내를 표시할 상태입니다.'
            : '초대 토큰을 검증하고 설치·로그인 복귀 후 연결할 화면입니다.',
        showBack: false,
        actions: const [
          SkeletonAction('연결 완료', RouteNames.partnerCalendar, replace: true),
        ],
      );
}
