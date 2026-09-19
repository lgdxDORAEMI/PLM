import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/partner_morning_report.dart';
import '../services/partner_morning_report_service.dart';

enum PartnerMorningReportState {
  loading,
  data,
  empty,
  authError,
  serverError,
  error,
}

class PartnerMorningReportController extends ChangeNotifier {
  PartnerMorningReportController({required this.service, required this.date});

  final PartnerMorningReportService service;
  final DateTime date;

  PartnerMorningReportState _state = PartnerMorningReportState.loading;
  PartnerMorningReport? _report;

  PartnerMorningReportState get state => _state;
  PartnerMorningReport? get report => _report;

  /// HTTP 상태를 화면이 구분할 수 있는 리포트 상태로 변환한다.
  Future<void> load() async {
    _state = PartnerMorningReportState.loading;
    notifyListeners();
    try {
      _report = await service.fetch(date);
      _state = _report == null
          ? PartnerMorningReportState.empty
          : PartnerMorningReportState.data;
    } on ApiException catch (error) {
      _report = null;
      _state = switch (error.statusCode) {
        401 || 403 => PartnerMorningReportState.authError,
        503 => PartnerMorningReportState.serverError,
        _ => PartnerMorningReportState.error,
      };
    } on Object {
      _report = null;
      _state = PartnerMorningReportState.error;
    }
    notifyListeners();
  }
}
