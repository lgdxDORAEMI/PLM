import 'package:flutter/material.dart';

/// 휠·트랙패드·터치 스크롤은 유지하고 플랫폼 자동 스크롤바만 숨긴다.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
