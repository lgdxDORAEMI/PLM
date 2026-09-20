import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/body_care_guide.dart';
import '../services/health_guide_service.dart';

enum BodyCareViewState { loading, data, empty, authError, serverError, error }

class BodyCareController extends ChangeNotifier {
  BodyCareController({required this.service});

  final HealthGuideService service;
  final Set<String> _completed = {};
  BodyCareViewState _state = BodyCareViewState.loading;
  BodyCareGuideData? _guide;
  String? _selectedArea;

  BodyCareViewState get state => _state;
  List<BodyLoad> get loads => _guide?.loads ?? const [];
  List<BodyCareActivity> get activities => _guide?.activities ?? const [];
  String get selectedArea => _selectedArea ?? '';
  bool isCompleted(String id) => _completed.contains(id);
  List<BodyCareActivity> get selectedActivities => activities
      .where((activity) => activity.area == selectedArea)
      .toList(growable: false);

  Future<void> load() async {
    _state = BodyCareViewState.loading;
    notifyListeners();
    try {
      _guide = await service.fetchGuide();
      _completed
        ..clear()
        ..addAll(
          activities
              .where((activity) => activity.completed)
              .map((activity) => activity.id),
        );
      if (activities.isEmpty) {
        _state = BodyCareViewState.empty;
      } else {
        _selectedArea = activities.first.area;
        _state = BodyCareViewState.data;
      }
    } on ApiException catch (error) {
      _state = switch (error.statusCode) {
        404 => BodyCareViewState.empty,
        401 || 403 => BodyCareViewState.authError,
        503 => BodyCareViewState.serverError,
        _ => BodyCareViewState.error,
      };
    } on Object {
      _state = BodyCareViewState.error;
    }
    notifyListeners();
  }

  void selectArea(String area) {
    if (_selectedArea == area) return;
    _selectedArea = area;
    notifyListeners();
  }

  Future<void> toggleCompleted(String id) async {
    final completed = !_completed.contains(id);
    completed ? _completed.add(id) : _completed.remove(id);
    notifyListeners();
    try {
      await service.setCompleted(id, completed);
    } on Object {
      completed ? _completed.remove(id) : _completed.add(id);
      _state = BodyCareViewState.error;
      notifyListeners();
    }
  }
}
