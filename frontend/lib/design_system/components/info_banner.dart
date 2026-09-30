import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum InfoBannerTone { subtle, neutral, info, success, warning, danger }

/// 안내·성공·경고·오류를 색상뿐 아니라 Icon과 Text로 함께 전달한다.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = InfoBannerTone.info,
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? message;
  final InfoBannerTone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone);
    return Semantics(
      container: true,
      liveRegion: tone == InfoBannerTone.danger,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.foreground.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon ?? _iconFor(tone),
                color: colors.foreground,
                size: compact ? 20 : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.labelLarge
                                  : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(color: colors.foreground),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        message!,
                        style: (compact
                                ? Theme.of(context).textTheme.bodySmall
                                : Theme.of(context).textTheme.bodyMedium)
                            ?.copyWith(color: colors.foreground),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerColors _colorsFor(InfoBannerTone tone) {
    return switch (tone) {
      InfoBannerTone.subtle => const _BannerColors(
        AppColors.surfaceSubtle,
        AppColors.textSecondary,
      ),
      InfoBannerTone.neutral => const _BannerColors(
        AppColors.surfaceSubtle,
        AppColors.textPrimary,
      ),
      InfoBannerTone.info => const _BannerColors(
        AppColors.infoBackground,
        AppColors.info,
      ),
      InfoBannerTone.success => const _BannerColors(
        AppColors.successBackground,
        AppColors.success,
      ),
      InfoBannerTone.warning => const _BannerColors(
        AppColors.warningBackground,
        AppColors.warning,
      ),
      InfoBannerTone.danger => const _BannerColors(
        AppColors.dangerBackground,
        AppColors.danger,
      ),
    };
  }

  IconData _iconFor(InfoBannerTone tone) {
    return switch (tone) {
      InfoBannerTone.subtle => Icons.info_outline,
      InfoBannerTone.neutral => Icons.info_outline,
      InfoBannerTone.info => Icons.info_outline,
      InfoBannerTone.success => Icons.check_circle_outline,
      InfoBannerTone.warning => Icons.warning_amber_rounded,
      InfoBannerTone.danger => Icons.error_outline,
    };
  }
}

class _BannerColors {
  const _BannerColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
