import 'package:flutter/foundation.dart';

import '../data/font_size_persistence.dart';
import '../models/app_font_size.dart';

/// 아내·남편 화면이 공유하는 앱 글자 크기 환경설정을 관리한다.
class AppTextScaleStore extends ChangeNotifier {
  AppTextScaleStore._()
    : _value = AppFontSize.fromStorage(readStoredFontSize());

  static final instance = AppTextScaleStore._();

  AppFontSize _value;
  AppFontSize get value => _value;

  void update(AppFontSize value) {
    if (_value == value) return;
    _value = value;
    writeStoredFontSize(value.name);
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _value = AppFontSize.standard;
    writeStoredFontSize(null);
    notifyListeners();
  }
}
