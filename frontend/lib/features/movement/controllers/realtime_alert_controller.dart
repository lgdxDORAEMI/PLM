import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/movement_alert.dart';
import '../services/movement_dashboard_service.dart';

enum MovementDashboardViewState {
  loading,
  data,
  empty,
  authError,
  domainError,
  serverError,
  error,
}

class RealtimeAlertController extends ChangeNotifier {
  RealtimeAlertController({required this.service});

  final MovementDashboardService service;
  MovementDashboardViewState _state = MovementDashboardViewState.loading;
  MovementDashboardData? _data;

  MovementDashboardViewState get state => _state;
  MovementDashboardData? get data => _data;
  List<MovementAlert> get todayAlerts => _data?.alerts ?? const [];

  Future<void> load() async {
    _state = MovementDashboardViewState.loading;
    notifyListeners();
    try {
      _data = await service.fetch();
      _state = MovementDashboardViewState.data;
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        401 || 403 => MovementDashboardViewState.authError,
        409 || 422 => MovementDashboardViewState.domainError,
        503 => MovementDashboardViewState.serverError,
        _ => MovementDashboardViewState.error,
      };
    } on Object {
      _state = MovementDashboardViewState.error;
    }
    notifyListeners();
  }
}
