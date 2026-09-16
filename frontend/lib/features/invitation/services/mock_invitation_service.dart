import '../models/invitation.dart';
import '../../../routing/route_names.dart';
import 'invitation_service.dart';

class MockInvitationService implements InvitationService {
  const MockInvitationService();

  @override
  Future<String> createLink() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return RouteNames.invitation(token: 'HS-28W');
  }

  @override
  Future<InvitationTokenStatus> validateToken(String? token) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (token == null || token.trim().isEmpty) {
      return InvitationTokenStatus.missing;
    }
    return switch (token.toLowerCase()) {
      'expired' => InvitationTokenStatus.expired,
      'used' => InvitationTokenStatus.used,
      'duplicate' => InvitationTokenStatus.duplicate,
      _ => InvitationTokenStatus.valid,
    };
  }

  @override
  Future<void> accept(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
