import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_spacing.dart';

/// 좁은 화면에서는 세로, 넓은 화면에서는 의미 있는 두 패널로 재배치한다.
class ResponsiveSplitView extends StatelessWidget {
  const ResponsiveSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 8,
    this.secondaryFlex = 4,
    this.splitAt = AppBreakpoints.desktop,
    this.gap = AppSpacing.xl,
    this.mobileSecondaryFirst = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;
  final double splitAt;
  final double gap;
  final bool mobileSecondaryFirst;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < splitAt) {
          final children = mobileSecondaryFirst
              ? [secondary, primary]
              : [primary, secondary];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              children.first,
              SizedBox(height: gap),
              children.last,
            ],
          );
        }
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            Expanded(flex: primaryFlex, child: primary),
            SizedBox(width: gap),
            Expanded(flex: secondaryFlex, child: secondary),
          ],
        );
      },
    );
  }
}
