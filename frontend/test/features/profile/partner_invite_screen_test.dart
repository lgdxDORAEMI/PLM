import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/screens/partner_invite_screen.dart';
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
}
