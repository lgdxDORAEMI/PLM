import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';

class PregnancyWeekTipCard extends StatelessWidget {
  const PregnancyWeekTipCard({
    super.key,
    required this.week,
    required this.tips,
    required this.caution,
    required this.todayTip,
  });

  final int week;
  final List<String> tips;
  final String caution;
  final String todayTip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$week주차에는 이런 시기예요',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: AppColors.primary300,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            const Divider(color: AppColors.primary100),
            const SizedBox(height: AppSpacing.sm),
            Text(
              caution,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('오늘 시도해보세요', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              todayTip,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
