import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/household_task.dart';

class HouseholdTaskCard extends StatelessWidget {
  const HouseholdTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.trailingLabel,
  });

  final HouseholdTask task;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final visual = _visual(task);
    return InkWell(
      key: ValueKey('household-task-${task.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: visual.background,
          border: Border.all(color: visual.foreground.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(_icon(task), color: visual.foreground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    task.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!))
            else if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: visual.foreground),
              )
            else if (onTap != null)
              Icon(
                task.selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: task.selected
                    ? visual.foreground
                    : AppColors.borderStrong,
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(HouseholdTask task) => switch (task.status) {
    HouseholdTaskStatus.done => Icons.check_circle,
    HouseholdTaskStatus.running => Icons.play_circle_fill,
    HouseholdTaskStatus.reserved => Icons.schedule,
    HouseholdTaskStatus.shared || HouseholdTaskStatus.confirmed => Icons.people,
    _ => switch (task.owner) {
      HouseholdTaskOwner.self => Icons.self_improvement,
      HouseholdTaskOwner.appliance => Icons.home_outlined,
      HouseholdTaskOwner.partner => Icons.volunteer_activism_outlined,
    },
  };

  _TaskVisual _visual(HouseholdTask task) => switch (task.status) {
    HouseholdTaskStatus.confirmed => const _TaskVisual(
      AppColors.info,
      AppColors.infoBackground,
    ),
    HouseholdTaskStatus.done => const _TaskVisual(
      AppColors.success,
      AppColors.successBackground,
    ),
    _ => switch (task.owner) {
      HouseholdTaskOwner.self => const _TaskVisual(
        AppColors.primary600,
        AppColors.primary50,
      ),
      HouseholdTaskOwner.appliance => const _TaskVisual(
        AppColors.categoryHome,
        AppColors.categoryHomeBackground,
      ),
      HouseholdTaskOwner.partner => const _TaskVisual(
        AppColors.categorySleep,
        AppColors.categorySleepBackground,
      ),
    },
  };
}

class _TaskVisual {
  const _TaskVisual(this.foreground, this.background);
  final Color foreground;
  final Color background;
}
