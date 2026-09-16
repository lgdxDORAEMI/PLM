import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Profile 6단계 중 현재 위치를 Text와 Progress bar로 함께 전달한다.
class ProfileProgress extends StatelessWidget {
  const ProfileProgress({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final current = step + 1;
    return Semantics(
      label: '프로필 설정 $current단계, 전체 6단계',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: current / 6,
              minHeight: 5,
              color: AppColors.primary500,
              backgroundColor: AppColors.primary100,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$current / 6',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
