import 'package:flutter/foundation.dart';

import '../models/daily_record.dart';
import '../services/record_service.dart';

enum DailyReportViewState { loading, ready, saving, sharing, empty, error }

class DailyReportController extends ChangeNotifier {
  DailyReportController({required this.service, required this.date});

  final RecordService service;
  final DateTime date;
  DailyReportViewState _state = DailyReportViewState.loading;
  DailyRecord? _record;

  DailyReportViewState get state => _state;
  DailyRecord? get record => _record;

  Future<void> load() async {
    _state = DailyReportViewState.loading;
    notifyListeners();
    try {
      _record = await service.fetchRecord(date);
      _state = _record == null
          ? DailyReportViewState.empty
          : DailyReportViewState.ready;
    } on Object {
      _state = DailyReportViewState.error;
    }
    notifyListeners();
  }

  Future<bool> save() => _runAction(
    DailyReportViewState.saving,
    () => service.saveRecord(_record!),
  );

  Future<bool> share() => _runAction(
    DailyReportViewState.sharing,
    () => service.shareRecord(_record!),
  );

  /// 저장과 공유는 동일한 진행/오류 상태 계약을 사용한다.
  Future<bool> _runAction(
    DailyReportViewState progress,
    Future<void> Function() action,
  ) async {
    if (_record == null) return false;
    _state = progress;
    notifyListeners();
    try {
      await action();
      _state = DailyReportViewState.ready;
      notifyListeners();
      return true;
    } on Object {
      _state = DailyReportViewState.error;
      notifyListeners();
      return false;
    }
  }
}
