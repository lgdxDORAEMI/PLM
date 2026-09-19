import '../../../core/network/api_client.dart';
import '../../../routing/route_names.dart';
import '../models/invitation.dart';
import 'invitation_service.dart';

/// Uses the account invitation endpoints without a separate validation call.
class ApiInvitationService implements InvitationService {
  ApiInvitationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<String> createLink() async {
    final response = await _client.post('/api/v1/account/partner-invitations');
    final url = response?['invitation_url']?.toString();
    if (url == null || url.isEmpty) throw StateError('초대 링크가 없습니다.');
    final token = Uri.parse(url).queryParameters['token'];
    if (token == null || token.isEmpty) throw StateError('초대 토큰이 없습니다.');
    return Uri.base.resolve(RouteNames.invitation(token: token)).toString();
  }

  @override
  Future<InvitationTokenStatus> validateToken(String? token) async =>
      token == null || token.trim().isEmpty
      ? InvitationTokenStatus.missing
      : InvitationTokenStatus.valid;

  @override
  Future<void> accept(String token) async {
    final encoded = Uri.encodeComponent(token);
    await _client.post('/api/v1/account/partner-invitations/$encoded/accept');
  }
}
