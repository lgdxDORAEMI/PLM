import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/daily_record.dart';

class RoutineRecordCard extends StatelessWidget {
  const RoutineRecordCard({super.key, required this.record});
  final RoutineRecord record;

  @override
  Widget build(BuildContext context) {
    final skipped = record.status == RoutineRecordStatus.skipped;
    final visual = _categoryVisual(record.category);
    return Opacity(
      opacity: skipped ? .55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Row(
          spacing: AppSpacing.md,
          children: [
            // 시안: 분야 라벨을 42 사각 배지로 통일.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _categoryLabel(record.category),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: visual.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    record.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.43,
                    ),
                  ),
                  Text(
                    skipped ? '오늘은 건너뜀' : '완료',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (record.completedByPartner)
              const AppBadge(label: '남편', tone: AppBadgeTone.info),
          ],
        ),
      ),
    );
  }

  /// 분야 배지 색(시안: 카테고리 색 40% 배경 + 카테고리 색 글자).
  ({Color foreground, Color background}) _categoryVisual(
    RecordCategory category,
  ) {
    final color = switch (category) {
      RecordCategory.meal => AppColors.categoryMeal,
      RecordCategory.household => AppColors.categoryHousehold,
      RecordCategory.health => AppColors.categoryHealth,
      RecordCategory.sleep => AppColors.categorySleep,
    };
    return (foreground: color, background: color.withValues(alpha: 0.4));
  }

  String _categoryLabel(RecordCategory category) => switch (category) {
    RecordCategory.meal => '식사',
    RecordCategory.household => '가사',
    RecordCategory.health => '건강',
    RecordCategory.sleep => '수면',
  };
}
