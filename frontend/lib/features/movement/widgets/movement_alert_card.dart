import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/movement_alert.dart';

class MovementAlertCard extends StatelessWidget {
  const MovementAlertCard({
    super.key,
    required this.alert,
    required this.onTap,
  });
  final MovementAlert alert;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final high = alert.level == MovementAlertLevel.high;
    final color = high ? AppColors.danger : AppColors.warning;
    return InkWell(
      key: ValueKey('movement-alert-${alert.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: high
                  ? AppColors.dangerBackground
                  : AppColors.warningBackground,
              foregroundColor: color,
              child: const Icon(Icons.priority_high),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    alert.suggestion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
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
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
