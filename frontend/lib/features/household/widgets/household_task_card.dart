import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
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
    this.selectable = false,
  });

  final HouseholdTask task;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailingLabel;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final visual = _visual(task);
    return AppInkWell(
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    task.applianceNames.isNotEmpty
                        ? task.applianceNames.join(' · ')
                        : task.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              OutlinedButton(
                key: ValueKey('household-action-${task.id}'),
                onPressed: onAction,
                // 시안: pill · borderStrong · primary600 14 Medium, 높이 40.
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.borderStrong),
                  foregroundColor: AppColors.primary600,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
                child: Text(actionLabel!),
              )
            else if (trailingLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: visual.foreground.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  trailingLabel!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: visual.foreground),
                ),
              )
            else if (selectable)
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
    HouseholdTaskStatus.shared => const _TaskVisual(
      AppColors.categoryPartner,
      AppColors.categoryPartnerBackground,
    ),
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
      // 시안: 가족 공유 카드는 sleep 색 아이콘 + info 배경.
      HouseholdTaskOwner.partner => const _TaskVisual(
        AppColors.categorySleep,
        AppColors.infoBackground,
      ),
    },
  };
}

class _TaskVisual {
  const _TaskVisual(this.foreground, this.background);
  final Color foreground;
  final Color background;
}
