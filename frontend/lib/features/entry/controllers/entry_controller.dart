import 'package:flutter/foundation.dart';

import '../../../routing/route_context.dart';
import '../services/entry_service.dart';

enum EntryViewState { loading, ready, error }

/// 앱 진입 시 역할과 가입 상태를 조회하고 복구 가능한 상태로 노출한다.
class EntryController extends ChangeNotifier {
  EntryController({required this.service});

  final EntryService service;
  EntryViewState _state = EntryViewState.loading;
  AppLaunchState? _launchState;

  EntryViewState get state => _state;
  AppLaunchState? get launchState => _launchState;

  /// Accepts a bootstrap result already loaded during automatic sign-in.
  void complete(AppLaunchState launchState) {
    _launchState = launchState;
    _state = EntryViewState.ready;
    notifyListeners();
  }

  Future<void> load() async {
    _state = EntryViewState.loading;
    notifyListeners();
    try {
      _launchState = await service.resolveLaunchState();
      _state = EntryViewState.ready;
    } on Object {
      _state = EntryViewState.error;
    }
    notifyListeners();
  }
}
