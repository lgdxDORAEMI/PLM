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
    this.todayTip,
  });

  final int week;
  final List<String> tips;
  final String caution;

  /// 없으면 '오늘 시도해보세요' 칸을 숨긴다(09-22 시안: 주의 문구 한 줄만).
  final String? todayTip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$week주차에는 이런 시기예요',
              // 홈 루틴 카드 제목과 같은 18 Bold.
              style: const TextStyle(
                color: AppColors.primary700,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.71,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              caution,
              style: const TextStyle(
                color: AppColors.primary700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.71,
              ),
            ),
            if (todayTip case final tip? when tip.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('오늘 시도해보세요', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tip,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
