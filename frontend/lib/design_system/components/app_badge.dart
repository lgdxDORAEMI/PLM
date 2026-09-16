import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum AppBadgeTone {
  neutral,
  primary,
  info,
  success,
  warning,
  danger,
  meal,
  home,
  body,
  sleep,
}

/// Category와 Status label에 공통으로 쓰되 의미 Mapping은 Feature가 결정한다.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colors.foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(AppBadgeTone tone) {
    return switch (tone) {
      AppBadgeTone.neutral => const _BadgeColors(
        AppColors.surfaceSubtle,
        AppColors.textSecondary,
      ),
      AppBadgeTone.primary => const _BadgeColors(
        AppColors.primary100,
        AppColors.primary700,
      ),
      AppBadgeTone.info => const _BadgeColors(
        AppColors.infoBackground,
        AppColors.info,
      ),
      AppBadgeTone.success => const _BadgeColors(
        AppColors.successBackground,
        AppColors.success,
      ),
      AppBadgeTone.warning => const _BadgeColors(
        AppColors.warningBackground,
        AppColors.warning,
      ),
      AppBadgeTone.danger => const _BadgeColors(
        AppColors.dangerBackground,
        AppColors.danger,
      ),
      AppBadgeTone.meal => const _BadgeColors(
        AppColors.categoryMealBackground,
        AppColors.categoryMeal,
      ),
      AppBadgeTone.home => const _BadgeColors(
        AppColors.categoryHomeBackground,
        AppColors.categoryHome,
      ),
      AppBadgeTone.body => const _BadgeColors(
        AppColors.categoryBodyBackground,
        AppColors.categoryBody,
      ),
      AppBadgeTone.sleep => const _BadgeColors(
        AppColors.categorySleepBackground,
        AppColors.categorySleep,
      ),
    };
  }
}

class _BadgeColors {
  const _BadgeColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
