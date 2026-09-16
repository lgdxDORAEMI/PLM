import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_badge.dart';
import 'app_card.dart';

/// 가사·건강·리포트에서 반복되는 안내 Task의 공통 표현을 제공한다.
class GuideTaskCard extends StatelessWidget {
  const GuideTaskCard({
    super.key,
    required this.title,
    required this.icon,
    this.description,
    this.badgeLabel,
    this.badgeTone = AppBadgeTone.neutral,
    this.completed = false,
    this.actionLabel,
    this.onAction,
  }) : assert(
         actionLabel == null || onAction != null,
         'actionLabel을 제공하면 onAction도 필요합니다.',
       );

  final String title;
  final IconData icon;
  final String? description;
  final String? badgeLabel;
  final AppBadgeTone badgeTone;
  final bool completed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title, ${completed ? '완료' : '미완료'}',
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              completed ? Icons.check_circle : icon,
              color: completed ? AppColors.success : AppColors.primary600,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppBadge(label: badgeLabel!, tone: badgeTone),
                      ],
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
