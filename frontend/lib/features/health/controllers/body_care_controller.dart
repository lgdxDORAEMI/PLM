import 'package:flutter/foundation.dart';

class BodyCareController extends ChangeNotifier {
  final Set<String> _completed = {};
  String _selectedArea = '허리';

  String get selectedArea => _selectedArea;
  bool isCompleted(String id) => _completed.contains(id);

  void selectArea(String area) {
    if (_selectedArea == area) return;
    _selectedArea = area;
    notifyListeners();
  }

  void toggleCompleted(String id) {
    _completed.contains(id) ? _completed.remove(id) : _completed.add(id);
    notifyListeners();
  }
}
