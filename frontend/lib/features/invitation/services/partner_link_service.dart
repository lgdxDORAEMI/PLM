import '../models/partner_link.dart';

abstract interface class PartnerLinkService {
  Future<PartnerLink> fetch();

  /// 09-29: 초기화 후 남편 화면에 아내 기록을 다시 공개한다.
  Future<void> share();
}
