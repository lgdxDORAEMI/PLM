import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/body_care_guide.dart';

class MovementGuideCard extends StatelessWidget {
  const MovementGuideCard({
    super.key,
    required this.activity,
    required this.completed,
    required this.onOpen,
    required this.onComplete,
  });
  final BodyCareActivity activity;
  final bool completed;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.borderSubtle),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.categoryBodyBackground,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const SizedBox.square(
            dimension: 52,
            child: Icon(Icons.accessibility_new, color: AppColors.categoryBody),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                activity.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('body-guide-${activity.id}'),
          tooltip: '자세 보기',
          onPressed: onOpen,
          icon: const Icon(
            Icons.play_circle_outline,
            color: AppColors.categoryBody,
          ),
        ),
        IconButton(
          key: ValueKey('body-complete-${activity.id}'),
          tooltip: completed ? '완료 취소' : '완료',
          onPressed: onComplete,
          icon: Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? AppColors.success : AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}
