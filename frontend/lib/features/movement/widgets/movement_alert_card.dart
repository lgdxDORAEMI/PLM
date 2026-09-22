import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/movement_alert.dart';

/// 부담 수준별 색상·아이콘. 개별 카드와 그룹 요약 카드가 같이 쓴다.
(Color, Color, IconData) alertLevelStyle(MovementAlertLevel level) =>
    switch (level) {
      MovementAlertLevel.high => (
        AppColors.danger,
        AppColors.dangerBackground,
        Icons.priority_high,
      ),
      MovementAlertLevel.caution => (
        AppColors.warning,
        AppColors.warningBackground,
        Icons.priority_high,
      ),
      MovementAlertLevel.neutral => (
        AppColors.info,
        AppColors.infoBackground,
        Icons.priority_high,
      ),
    };

class MovementAlertCard extends StatelessWidget {
  const MovementAlertCard({super.key, required this.alert, this.onTap, this.interactionKey});
  final MovementAlert alert;
  final VoidCallback? onTap;
  final Key? interactionKey;
  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = alertLevelStyle(alert.level);
    final content = Ink(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: background,
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  alert.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  alert.suggestion,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            alert.time,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
    final key = interactionKey ?? ValueKey('movement-alert-${alert.id}');
    if (onTap == null) return KeyedSubtree(key: key, child: content);
    return AppInkWell(
      key: key,
      onTap: onTap!,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: content,
    );
  }
}
