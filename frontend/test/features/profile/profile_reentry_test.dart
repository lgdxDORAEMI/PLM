import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/routing/app_session.dart';

void main() {
  test('초기화 후 프로필 재입력은 같은 계정에만 적용된다', () {
    final auth = AuthSessionStore.instance;
    final profile = ProfileStore.instance;

    void useAccount(String id) => auth.update(
      accountId: id,
      roles: {ActiveRole.wife},
      husbandLinked: true,
      profileComplete: true,
    );

    useAccount('reentry-wife');
    profile.save(ProfileDraft.mockEdit());
    profile.requireReentry();
    profile.reset();
    expect(profile.requiresReentry, isTrue);
    expect(profile.awaitsResetRoutine, isTrue);
    expect(profile.hasProfile, isFalse);

    useAccount('other-wife');
    expect(profile.requiresReentry, isFalse);
    expect(profile.awaitsResetRoutine, isFalse);

    useAccount('reentry-wife');
    profile.completeReentry();
    expect(profile.requiresReentry, isFalse);
    expect(profile.awaitsResetRoutine, isTrue);
    profile.completeResetRoutine();
    expect(profile.awaitsResetRoutine, isFalse);
    profile.reset();
    useAccount('demo-wife');
  });
}
