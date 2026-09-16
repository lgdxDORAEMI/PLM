import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Home의 핵심 정보인 임신 주차를 원형 Geometry로 강조한다.
class PregnancyWeekHero extends StatelessWidget {
  const PregnancyWeekHero({super.key, required this.week});

  final int week;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '현재 임신 $week주차',
      child: Center(
        child: Container(
          width: 188,
          height: 188,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary100,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$week',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primary600,
                    fontSize: 48,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '주차',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
