import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum AppStatusTone { neutral, info, success, warning, danger }

/// 색상과 아이콘, 문구를 함께 사용해 inline 상태를 전달한다.
class AppStatus extends StatelessWidget {
  const AppStatus({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.compact = false,
  });

  final String label;
  final AppStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = _visual(tone);
    return Semantics(
      label: label,
      liveRegion: tone == AppStatusTone.danger,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(
            compact ? AppRadius.pill : AppRadius.input,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.md : AppSpacing.lg,
            vertical: compact ? AppSpacing.xs : AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(visual.icon, size: 18, color: visual.foreground),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: visual.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusVisual _visual(AppStatusTone tone) => switch (tone) {
    AppStatusTone.neutral => const _StatusVisual(
      AppColors.surfaceSubtle,
      AppColors.textSecondary,
      Icons.info_outline,
    ),
    AppStatusTone.info => const _StatusVisual(
      AppColors.infoBackground,
      AppColors.info,
      Icons.info_outline,
    ),
    AppStatusTone.success => const _StatusVisual(
      AppColors.successBackground,
      AppColors.success,
      Icons.check_circle_outline,
    ),
    AppStatusTone.warning => const _StatusVisual(
      AppColors.warningBackground,
      AppColors.warning,
      Icons.warning_amber_rounded,
    ),
    AppStatusTone.danger => const _StatusVisual(
      AppColors.dangerBackground,
      AppColors.danger,
      Icons.error_outline,
    ),
  };
}

class _StatusVisual {
  const _StatusVisual(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;
}
