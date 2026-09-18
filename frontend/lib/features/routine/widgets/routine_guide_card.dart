import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/daily_routine.dart';

/// Home에서 Guide 상세 화면으로 이동하는 Routine 전용 카드다.
class RoutineGuideCard extends StatelessWidget {
  const RoutineGuideCard({super.key, required this.item, required this.onTap});

  final RoutineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(item.type);
    return Semantics(
      button: true,
      label: '${item.title}, ${item.description}',
      child: AppInkWell(
        key: ValueKey('routine-card-${item.type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: visual.foreground,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(visual.icon, color: visual.foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  _RoutineVisual _visualFor(RoutineType type) {
    return switch (type) {
      RoutineType.meal => const _RoutineVisual(
        icon: Icons.ramen_dining_outlined,
        foreground: AppColors.categoryMeal,
        background: AppColors.categoryMealBackground,
      ),
      RoutineType.household => const _RoutineVisual(
        icon: Icons.local_laundry_service_outlined,
        foreground: AppColors.categoryHome,
        background: AppColors.categoryHomeBackground,
      ),
      RoutineType.health => const _RoutineVisual(
        icon: Icons.monitor_heart_outlined,
        foreground: AppColors.categoryBody,
        background: AppColors.categoryBodyBackground,
      ),
      RoutineType.sleep => const _RoutineVisual(
        icon: Icons.bedtime_outlined,
        foreground: AppColors.categorySleep,
        background: AppColors.categorySleepBackground,
      ),
    };
  }
}

class _RoutineVisual {
  const _RoutineVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}
