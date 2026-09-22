import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/daily_routine.dart';

class RoutineProgress extends StatelessWidget {
  const RoutineProgress({super.key, required this.items});

  final List<RoutineItem> items;

  @override
  Widget build(BuildContext context) {
    // 분야(식사·가사·건강·수면) 단위로 센다. 분야의 모든 항목이 완료돼야 완료다.
    final groups = <RoutineType, List<RoutineItem>>{};
    for (final item in items) {
      (groups[item.type] ??= []).add(item);
    }
    final total = groups.length;
    final completed = groups.values
        .where((g) => g.every((i) => i.status == RoutineStatus.completed))
        .length;
    final progress = total == 0 ? 0.0 : completed / total;
    return Semantics(
      label: '오늘 루틴 $total개 분야 중 $completed개 완료',
      child: Column(
        key: const ValueKey('home-routine-progress'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '루틴 진행도',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 2,
                  ),
                ),
              ),
              Text(
                '$completed / $total 완료',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceSubtle,
          ),
        ],
      ),
    );
  }
}
