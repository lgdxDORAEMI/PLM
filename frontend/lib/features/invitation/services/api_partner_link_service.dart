import '../../../core/network/api_client.dart';
import '../models/partner_link.dart';
import 'partner_link_service.dart';

class ApiPartnerLinkService implements PartnerLinkService {
  ApiPartnerLinkService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<PartnerLink> fetch() async {
    final response = await _client.get('/api/v1/account/partner-link');
    return response == null
        ? const PartnerLink(linked: false)
        : PartnerLink.fromJson(response);
  }
}
