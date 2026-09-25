import 'package:flutter/material.dart';

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
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox.square(
                  dimension: 52,
                  child: summary.imageUrl == null
                      ? ColoredBox(
                          color: visual.background,
                          child: Icon(
                            visual.icon,
                            color: visual.foreground,
                            size: 30,
                          ),
                        )
                      : Image.network(
                          summary.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : ColoredBox(
                                  color: visual.background,
                                  child: Icon(
                                    visual.icon,
                                    color: visual.foreground,
                                    size: 30,
                                  ),
                                ),
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: visual.background,
                            child: Icon(
                              visual.icon,
                              color: visual.foreground,
                              size: 30,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      summary.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      summary.summary,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.isCurrent) ...[
                // 시안: 식사 색 40% 배경 + primary700 12 SemiBold.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.categoryMeal.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      '지금',
                      style: TextStyle(
                        color: AppColors.primary700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// 시안: 아침→밤으로 갈수록 식사 색이 진해진다(20%·40%·75%·100%).
  _PeriodVisual _visualFor(MealPeriod period) {
    const meal = AppColors.categoryMeal;
    return switch (period) {
      MealPeriod.breakfast => _PeriodVisual(
        Icons.wb_sunny_outlined,
        AppColors.warning,
        meal.withValues(alpha: 0.2),
      ),
      MealPeriod.lunch => _PeriodVisual(
        Icons.lunch_dining_outlined,
        meal,
        meal.withValues(alpha: 0.4),
      ),
      MealPeriod.dinner => _PeriodVisual(
        Icons.dinner_dining_outlined,
        AppColors.textInverse,
        meal.withValues(alpha: 0.75),
      ),
      MealPeriod.snack => const _PeriodVisual(
        Icons.bedtime_outlined,
        AppColors.textInverse,
        meal,
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
