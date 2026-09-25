import 'package:flutter/material.dart';

import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/body_care_guide.dart';
import 'video_thumbnail.dart';

class MovementGuideCard extends StatelessWidget {
  const MovementGuideCard({
    super.key,
    required this.activity,
    required this.completed,
    this.featured = false,
    this.showCompletion = true,
    required this.onOpen,
    required this.onComplete,
  });
  final BodyCareActivity activity;
  final bool completed;
  final bool featured;
  final bool showCompletion;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('health-activity-${activity.id}'),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.borderSubtle),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: featured ? _buildFeatured(context) : _buildCompact(context),
  );

  Widget _buildFeatured(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppInkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: VideoThumbnail(youtubeId: activity.video?.youtubeId, height: 132),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(activity.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        activity.description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      if (showCompletion) ...[
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: ValueKey('body-complete-${activity.id}'),
            onPressed: onComplete,
            icon: Icon(completed ? Icons.check_circle : Icons.circle_outlined),
            label: Text(completed ? '활동 완료됨' : '활동 완료'),
          ),
        ),
      ],
    ],
  );

  Widget _buildCompact(BuildContext context) => Row(
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
            Text(activity.title, style: Theme.of(context).textTheme.titleSmall),
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
      if (showCompletion)
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
  );
}

