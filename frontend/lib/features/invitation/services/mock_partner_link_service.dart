import '../data/partner_connection_store.dart';
import '../models/partner_link.dart';
import 'partner_link_service.dart';

class MockPartnerLinkService implements PartnerLinkService {
  MockPartnerLinkService({PartnerConnectionStore? store})
    : _store = store ?? PartnerConnectionStore.instance;

  final PartnerConnectionStore _store;

  @override
  Future<PartnerLink> fetch() async => PartnerLink(linked: _store.isLinked);
}
