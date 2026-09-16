enum AppWindowSize { mobile, tablet, desktop, wide }

/// DESIGN.md의 Flutter Web 반응형 구간을 한 곳에서 관리한다.
abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double wide = 1440;

  static AppWindowSize sizeFor(double width) {
    if (width >= wide) return AppWindowSize.wide;
    if (width >= desktop) return AppWindowSize.desktop;
    if (width >= tablet) return AppWindowSize.tablet;
    return AppWindowSize.mobile;
  }
}
