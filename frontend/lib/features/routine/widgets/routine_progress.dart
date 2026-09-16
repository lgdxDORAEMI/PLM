import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/daily_routine.dart';

class RoutineProgress extends StatelessWidget {
  const RoutineProgress({super.key, required this.items});

  final List<RoutineItem> items;

  @override
  Widget build(BuildContext context) {
    final completed = items
        .where((item) => item.status == RoutineStatus.completed)
        .length;
    final progress = items.isEmpty ? 0.0 : completed / items.length;
    return Semantics(
      label: '오늘 루틴 ${items.length}개 중 $completed개 완료',
      child: Column(
        key: const ValueKey('home-routine-progress'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘의 진행',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$completed / ${items.length} 완료',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.primary700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
