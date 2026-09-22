import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/meal_guide.dart';

class MealInfoSection extends StatelessWidget {
  const MealInfoSection({super.key, required this.items});

  final List<MealCaution> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              '오늘 조심할 것',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            Text(
              '무조건 금지가 아니라, 이유와 허용 범위를 알려드려요',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: AppColors.categoryMeal,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _CautionRow(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: 1, color: AppColors.categoryMeal),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CautionRow extends StatelessWidget {
  const _CautionRow({required this.item});

  final MealCaution item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 10, color: AppColors.categoryMeal),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          if (item.badge != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppBadge(label: item.badge!, tone: AppBadgeTone.warning),
          ],
        ],
      ),
    );
  }
}
