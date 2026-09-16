import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class PartnerInviteScreen extends ProductSkeletonScreen {
  const PartnerInviteScreen({
    super.key,
    required InviteEntryContext entryContext,
  }) : super(
         requirementIds: const ['W-INVITE-001', 'W-INVITE-002'],
         title: '배우자 초대',
         description: entryContext == InviteEntryContext.onboarding
             ? '최초 등록 후 초대 공유 또는 나중에 하기를 선택합니다.'
             : '미연동 상태에서 배우자 초대를 다시 진행합니다.',
         actions: entryContext == InviteEntryContext.onboarding
             ? const [
                 SkeletonAction(
                   '링크 보내기 또는 나중에',
                   RouteNames.wifeHome,
                   replace: true,
                 ),
               ]
             : const [
                 SkeletonAction(
                   '초대 처리 후 이전 화면',
                   RouteNames.wifeHome,
                   pop: true,
                 ),
               ],
       );
}
