import '../models/invitation.dart';

abstract interface class InvitationService {
  Future<String> createLink();

  Future<InvitationTokenStatus> validateToken(String? token);

  Future<void> accept(String token);
}
