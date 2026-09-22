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
    // 식사 가이드 상세(compact=false)만 시안 스타일. 챗봇 대안 카드(compact)는 기존 그대로.
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.pageMobile),
      borderColor: compact ? null : AppColors.categoryMeal,
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
            style: compact
                ? Theme.of(context).textTheme.titleLarge
                : const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.41,
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recommendation.description,
            style: compact
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  )
                : const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 17,
                    height: 1.59,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in recommendation.nutritionTags)
                if (compact)
                  AppBadge(label: tag, tone: _toneFor(tag))
                else
                  _DetailTag(
                    label: tag,
                    meal: _toneFor(tag) == AppBadgeTone.meal,
                  ),
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

/// 상세 화면 영양 태그(시안): 식사 톤은 식사 색 40% 배경, 나머지는 info 톤. 14 SemiBold.
class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.label, required this.meal});

  final String label;
  final bool meal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: meal
            ? AppColors.categoryMeal.withValues(alpha: 0.4)
            : AppColors.infoBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: meal ? AppColors.categoryMeal : AppColors.info,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.43,
          ),
        ),
      ),
    );
  }
}
