import 'package:flutter/material.dart';

/// 플랫폼 접근성 배율을 보존하면서 앱에서 선택한 글자 배율을 추가 적용한다.
class AppTextScaleFrame extends StatelessWidget {
  const AppTextScaleFrame({
    super.key,
    required this.appScale,
    required this.child,
  });

  final double appScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final platformScale = mediaQuery.textScaler.scale(16) / 16;
    final combinedScale = (platformScale * appScale).clamp(0.8, 3.0);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(combinedScale)),
      child: child,
    );
  }
}
