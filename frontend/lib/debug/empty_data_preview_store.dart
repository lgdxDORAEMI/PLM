import 'package:flutter/foundation.dart';

/// Mock 원본을 변경하지 않고 조회 화면의 빈 상태를 점검하는 런타임 전용 상태다.
class EmptyDataPreviewStore extends ChangeNotifier {
  EmptyDataPreviewStore._();

  static final instance = EmptyDataPreviewStore._();

  static const requiredTapCount = 5;
  static const _maximumTapGap = Duration(seconds: 1);

  bool _enabled = false;
  int _consecutiveTapCount = 0;
  DateTime? _lastTapAt;

  bool get enabled => _enabled;

  /// 제한 시간 안에 제목을 다섯 번 누르면 모드를 전환하고 새 상태를 반환한다.
  /// 전환되지 않은 탭은 null을 반환한다.
  bool? registerTitleTap({DateTime? now}) {
    final tappedAt = now ?? DateTime.now();
    final lastTapAt = _lastTapAt;
    if (lastTapAt == null || tappedAt.difference(lastTapAt) > _maximumTapGap) {
      _consecutiveTapCount = 1;
    } else {
      _consecutiveTapCount += 1;
    }
    _lastTapAt = tappedAt;

    if (_consecutiveTapCount < requiredTapCount) return null;

    _consecutiveTapCount = 0;
    _lastTapAt = null;
    _enabled = !_enabled;
    notifyListeners();
    return _enabled;
  }

  @visibleForTesting
  void reset() {
    _enabled = false;
    _consecutiveTapCount = 0;
    _lastTapAt = null;
    notifyListeners();
  }
}
