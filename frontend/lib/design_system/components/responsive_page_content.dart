import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_spacing.dart';

/// 모바일 여백과 Web 최대 폭을 일관되게 적용하는 화면 본문 컨테이너다.
class ResponsivePageContent extends StatelessWidget {
  const ResponsivePageContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.alignment = Alignment.topCenter,
  });

  const ResponsivePageContent.form({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= AppBreakpoints.tablet
            ? 28.0
            : AppSpacing.pageMobile;
        return Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
