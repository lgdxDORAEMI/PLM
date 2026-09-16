import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/section_header.dart';
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
        const SectionHeader(
          title: '오늘 조심할 것',
          description: '무조건 금지가 아니라, 이유와 허용 범위를 알려드려요',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _CautionRow(item: items[index]),
                if (index != items.length - 1)
                  const Divider(height: 1, color: AppColors.borderSubtle),
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
            child: Icon(Icons.circle, size: 10, color: AppColors.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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
