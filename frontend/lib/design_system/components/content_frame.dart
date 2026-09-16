import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_spacing.dart';

/// Mobile부터 Wide Web까지 동일한 grid margin과 최대 폭을 제공한다.
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = AppBreakpoints.sizeFor(constraints.maxWidth);
        final margin = switch (size) {
          AppWindowSize.mobile => AppSpacing.pageMobile,
          AppWindowSize.tablet => AppSpacing.pageTablet,
          AppWindowSize.desktop => AppSpacing.pageDesktop,
          AppWindowSize.wide => AppSpacing.pageWide,
        };
        return Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
