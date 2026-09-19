import '../models/partner_link.dart';

abstract interface class PartnerLinkService {
  Future<PartnerLink> fetch();
}
