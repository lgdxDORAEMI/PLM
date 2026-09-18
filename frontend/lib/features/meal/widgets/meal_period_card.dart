import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/meal_guide.dart';

class MealPeriodCard extends StatelessWidget {
  const MealPeriodCard({super.key, required this.summary, required this.onTap});

  final MealPeriodSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(summary.period);
    return Semantics(
      button: true,
      label: '${summary.label}, ${summary.summary}',
      child: AppInkWell(
        key: ValueKey('meal-period-${summary.period.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(
              color: summary.isCurrent
                  ? AppColors.primary400
                  : AppColors.borderSubtle,
              width: summary.isCurrent ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(visual.icon, color: visual.foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summary.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.isCurrent) ...[
                const AppBadge(label: '지금', tone: AppBadgeTone.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  _PeriodVisual _visualFor(MealPeriod period) {
    return switch (period) {
      MealPeriod.breakfast => const _PeriodVisual(
        Icons.wb_sunny_outlined,
        AppColors.warning,
        AppColors.warningBackground,
      ),
      MealPeriod.lunch => const _PeriodVisual(
        Icons.lunch_dining_outlined,
        AppColors.categoryMeal,
        AppColors.categoryMealBackground,
      ),
      MealPeriod.dinner => const _PeriodVisual(
        Icons.dinner_dining_outlined,
        AppColors.primary700,
        AppColors.primary50,
      ),
      MealPeriod.snack => const _PeriodVisual(
        Icons.bedtime_outlined,
        AppColors.categorySleep,
        AppColors.categorySleepBackground,
      ),
    };
  }
}

class _PeriodVisual {
  const _PeriodVisual(this.icon, this.foreground, this.background);

  final IconData icon;
  final Color foreground;
  final Color background;
}
