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
    return Opacity(
      opacity: skipped ? .55 : 1,
      child: AppCard(
        child: Row(
          children: [
            AppBadge(
              label: _categoryLabel(record.category),
              tone: _categoryTone(record.category),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    skipped ? '오늘은 건너뜀' : '완료',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
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

  String _categoryLabel(RecordCategory category) => switch (category) {
    RecordCategory.meal => '식사',
    RecordCategory.household => '가사',
    RecordCategory.health => '건강',
    RecordCategory.sleep => '수면',
  };

  AppBadgeTone _categoryTone(RecordCategory category) => switch (category) {
    RecordCategory.meal => AppBadgeTone.meal,
    RecordCategory.household => AppBadgeTone.home,
    RecordCategory.health => AppBadgeTone.body,
    RecordCategory.sleep => AppBadgeTone.sleep,
  };
}
