import '../models/partner_morning_report.dart';

abstract interface class PartnerMorningReportService {
  Future<PartnerMorningReport?> fetch(DateTime date);
}
