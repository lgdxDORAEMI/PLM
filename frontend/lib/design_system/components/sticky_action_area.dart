import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_spacing.dart';

/// Mobile CTA를 keyboard와 safe area 위에 안정적으로 고정한다.
class StickyActionArea extends StatelessWidget {
  const StickyActionArea({super.key, required this.child, this.raised = true});

  final Widget child;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: raised ? AppElevation.level2 : AppElevation.none,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.pageMobile,
          AppSpacing.md,
          AppSpacing.pageMobile,
          AppSpacing.lg,
        ),
        child: child,
      ),
    );
  }
}
