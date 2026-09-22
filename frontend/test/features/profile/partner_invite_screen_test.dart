import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/screens/partner_invite_screen.dart';
import 'package:plm_frontend/features/invitation/models/invitation.dart';
import 'package:plm_frontend/features/invitation/models/partner_link.dart';
import 'package:plm_frontend/features/invitation/services/invitation_service.dart';
import 'package:plm_frontend/features/invitation/services/partner_link_service.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  testWidgets('남편 초대 화면은 보이고 전송 버튼을 누를 때만 연동 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerInviteScreen(entryContext: InviteEntryContext.profileMenu),
      ),
    );

    expect(find.text('남편도 ThinQ에 연결해보세요'), findsOneWidget);
    expect(find.text('남편 초대장 전송은 연동이 필요합니다.'), findsNothing);

    final sendButton = find.byKey(const ValueKey('partner-invite-send'));
    await tester.scrollUntilVisible(
      sendButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(sendButton);
    await tester.pump();

    expect(find.text('남편 초대장 전송은 연동이 필요합니다.'), findsOneWidget);
    expect(find.text('초대장을 보냈어요'), findsNothing);
  });

  testWidgets('이미 연동된 계정은 초대 링크를 만들지 않고 버튼 후 연결 결과를 보여준다', (tester) async {
    final invitation = _CountingInvitationService();
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerInviteScreen(
          entryContext: InviteEntryContext.profileMenu,
          service: invitation,
          partnerLinkService: _LinkedPartnerService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('최준서님과 연결됐어요'), findsNothing);

    final send = find.byKey(const ValueKey('partner-invite-send'));
    await tester.scrollUntilVisible(
      send,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('최준서님과 연결됐어요'), findsOneWidget);
    expect(invitation.createCalls, 0);
  });
}

class _LinkedPartnerService implements PartnerLinkService {
  @override
  Future<PartnerLink> fetch() async =>
      const PartnerLink(linked: true, partnerDisplayName: '최준서');
}

class _CountingInvitationService implements InvitationService {
  int createCalls = 0;

  @override
  Future<String> createLink() async {
    createCalls += 1;
    return 'https://example.com/invite';
  }

  @override
  Future<InvitationTokenStatus> validateToken(String? token) async =>
      InvitationTokenStatus.valid;

  @override
  Future<void> accept(String token) async {}
}
