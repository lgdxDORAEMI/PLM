import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum AppCardVariant { outlined, subtle, raised }

/// 그림자 대신 border를 사용하는 표준 surface card다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.variant = AppCardVariant.outlined,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    final content = Container(
      decoration: BoxDecoration(
        color: switch (variant) {
          AppCardVariant.outlined || AppCardVariant.raised => AppColors.surface,
          AppCardVariant.subtle => AppColors.surfaceSubtle,
        },
        border: variant == AppCardVariant.outlined
            ? Border.all(color: AppColors.borderSubtle)
            : null,
        borderRadius: radius,
        boxShadow: variant == AppCardVariant.raised
            ? AppElevation.level1
            : AppElevation.none,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}
