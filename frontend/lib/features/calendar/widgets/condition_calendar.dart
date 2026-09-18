import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../report/models/daily_record.dart';

class ConditionCalendar extends StatelessWidget {
  const ConditionCalendar({
    super.key,
    required this.month,
    required this.records,
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime month;
  final List<DailyRecord> records;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leading = firstDay.weekday % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(child: Center(child: Text(label))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 44,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, index - leading + 1);
            final record = _recordFor(date);
            final selected = DateUtils.isSameDay(date, selectedDate);
            return Semantics(
              selected: selected,
              button: record != null,
              label:
                  '${date.day}일${record == null ? ', 기록 없음' : ', ${_levelLabel(record.conditionLevel)}'}',
              child: AppInkWell(
                key: ValueKey('calendar-day-${recordDateKey(date)}'),
                onTap: record == null ? null : () => onSelected(date),
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: record == null
                        ? Colors.transparent
                        : _levelColor(record.conditionLevel),
                    border: selected
                        ? Border.all(color: AppColors.primary600, width: 3)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: record == null
                          ? AppColors.textDisabled
                          : record.conditionLevel == ConditionLevel.difficult ||
                                record.conditionLevel == ConditionLevel.bad
                          ? AppColors.textInverse
                          : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  DailyRecord? _recordFor(DateTime date) {
    for (final record in records) {
      if (DateUtils.isSameDay(record.date, date)) return record;
    }
    return null;
  }

  String _levelLabel(ConditionLevel level) => switch (level) {
    ConditionLevel.good => '좋음',
    ConditionLevel.normal => '보통',
    ConditionLevel.bad => '나쁨',
    ConditionLevel.difficult => '힘듦',
  };

  Color _levelColor(ConditionLevel level) => switch (level) {
    ConditionLevel.good => AppColors.surfaceSubtle,
    ConditionLevel.normal => AppColors.primary100,
    ConditionLevel.bad => AppColors.primary300,
    ConditionLevel.difficult => AppColors.primary500,
  };
}

class ConditionLegend extends StatelessWidget {
  const ConditionLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('좋음', AppColors.surfaceSubtle),
      ('보통', AppColors.primary100),
      ('나쁨', AppColors.primary300),
      ('힘듦', AppColors.primary500),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          Text(
            '컨디션 지수',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          for (final entry in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: entry.$2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(entry.$1),
              ],
            ),
        ],
      ),
    );
  }
}
