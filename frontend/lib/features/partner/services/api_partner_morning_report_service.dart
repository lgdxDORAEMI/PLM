import '../../../core/network/api_client.dart';
import '../models/partner_morning_report.dart';
import 'partner_morning_report_service.dart';

class ApiPartnerMorningReportService implements PartnerMorningReportService {
  ApiPartnerMorningReportService({ApiClient? client})
    : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<PartnerMorningReport?> fetch(DateTime date) async {
    final response = await _client.get(
      '/api/v1/family/morning-reports/${_dateKey(date)}',
    );
    return response == null ? null : PartnerMorningReport.fromJson(response);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
