import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Home의 첫 맥락을 장식보다 정보 위계 중심으로 전달한다.
class PregnancyWeekHero extends StatelessWidget {
  const PregnancyWeekHero({
    super.key,
    required this.userName,
    required this.week,
  });

  final String userName;
  final int week;

  @override
  Widget build(BuildContext context) {
    final statusText = '$userName님,\n오늘 임신 $week주차예요';
    return Semantics(
      container: true,
      label: '$userName님, 현재 임신 $week주차',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREGNANCY CONTEXT',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(statusText, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            '오늘의 상태부터 확인하고, 필요한 일만 차분히 이어가요.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
