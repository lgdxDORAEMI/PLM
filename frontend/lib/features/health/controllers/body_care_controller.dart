import 'package:flutter/foundation.dart';

class BodyCareController extends ChangeNotifier {
  final Set<String> _completed = {};
  bool isCompleted(String id) => _completed.contains(id);
  void toggleCompleted(String id) {
    _completed.contains(id) ? _completed.remove(id) : _completed.add(id);
    notifyListeners();
  }
}
