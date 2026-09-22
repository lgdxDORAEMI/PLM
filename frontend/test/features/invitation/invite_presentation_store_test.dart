import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/invitation/data/invite_presentation_store.dart';
import 'package:plm_frontend/routing/app_session.dart';

void main() {
  test('오늘 초기화는 현재 계정의 가족 초대 확인 표시만 지운다', () {
    final auth = AuthSessionStore.instance;
    final invitations = InvitePresentationStore.instance;

    void useAccount(String id) => auth.update(
      accountId: id,
      roles: {ActiveRole.wife},
      husbandLinked: true,
      profileComplete: true,
    );

    useAccount('reset-wife');
    invitations.acknowledgeLinkedPartner();
    expect(invitations.isAcknowledged, isTrue);

    useAccount('other-wife');
    invitations.acknowledgeLinkedPartner();
    useAccount('reset-wife');
    invitations.resetForCurrentAccount();
    expect(invitations.isAcknowledged, isFalse);

    useAccount('other-wife');
    expect(invitations.isAcknowledged, isTrue);
    invitations.resetForCurrentAccount();
    useAccount('demo-wife');
  });
}
