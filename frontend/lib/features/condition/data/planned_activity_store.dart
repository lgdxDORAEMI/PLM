import 'package:flutter/foundation.dart';

class PlannedActivityStore extends ChangeNotifier {
  PlannedActivityStore._();

  static final PlannedActivityStore instance = PlannedActivityStore._();

  List<String> _activities = const [];

  List<String> get activities => List.unmodifiable(_activities);

  void save(Iterable<String> values) {
    _activities = List.unmodifiable(values);
    notifyListeners();
  }

  void clear() {
    _activities = const [];
    notifyListeners();
  }
}
