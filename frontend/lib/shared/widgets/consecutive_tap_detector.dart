import 'package:flutter/widgets.dart';

/// 제한 시간 안에 지정 횟수만큼 연속 탭했을 때만 숨겨진 테스트 동작을 실행한다.
class ConsecutiveTapDetector extends StatefulWidget {
  const ConsecutiveTapDetector({
    super.key,
    required this.child,
    required this.onTriggered,
    this.requiredTapCount = 5,
    this.maximumTapGap = const Duration(seconds: 1),
  });

  final Widget child;
  final VoidCallback onTriggered;
  final int requiredTapCount;
  final Duration maximumTapGap;

  @override
  State<ConsecutiveTapDetector> createState() => _ConsecutiveTapDetectorState();
}

class _ConsecutiveTapDetectorState extends State<ConsecutiveTapDetector> {
  int _tapCount = 0;
  DateTime? _lastTapAt;

  void _registerTap() {
    final tappedAt = DateTime.now();
    final lastTapAt = _lastTapAt;
    _tapCount =
        lastTapAt == null ||
            tappedAt.difference(lastTapAt) > widget.maximumTapGap
        ? 1
        : _tapCount + 1;
    _lastTapAt = tappedAt;

    if (_tapCount < widget.requiredTapCount) return;
    _tapCount = 0;
    _lastTapAt = null;
    widget.onTriggered();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _registerTap,
    child: widget.child,
  );
}
