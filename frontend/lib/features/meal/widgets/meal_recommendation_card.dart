import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/meal_guide.dart';

class MealRecommendationCard extends StatelessWidget {
  const MealRecommendationCard({
    super.key,
    required this.recommendation,
    this.compact = false,
  });

  final MealRecommendation recommendation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.pageMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const SizedBox(
                height: 132,
                child: Center(
                  child: Icon(
                    Icons.rice_bowl_outlined,
                    size: 64,
                    color: AppColors.categoryMeal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            recommendation.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recommendation.description,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in recommendation.nutritionTags)
                AppBadge(label: tag, tone: _toneFor(tag)),
            ],
          ),
        ],
      ),
    );
  }

  AppBadgeTone _toneFor(String tag) {
    if (tag.contains('단백질') || tag.contains('냄새')) {
      return AppBadgeTone.meal;
    }
    if (tag.contains('혈당')) return AppBadgeTone.primary;
    return AppBadgeTone.info;
  }
}
