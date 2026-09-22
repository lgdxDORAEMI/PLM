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
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    // 시안: 카테고리 색 40%.
                    color: visual.foreground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: SizedBox.square(
                    dimension: 52,
                    child: Icon(
                      visual.icon,
                      color: visual.foreground,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        item.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.71,
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
      ),
    );
  }

  _RoutineVisual _visualFor(RoutineType type) {
    return switch (type) {
      RoutineType.meal => const _RoutineVisual(
        icon: Icons.ramen_dining_outlined,
        foreground: AppColors.categoryMeal,
      ),
      RoutineType.household => const _RoutineVisual(
        icon: Icons.local_laundry_service_outlined,
        foreground: AppColors.categoryHome,
      ),
      RoutineType.health => const _RoutineVisual(
        icon: Icons.monitor_heart_outlined,
        foreground: AppColors.categoryBody,
      ),
      RoutineType.sleep => const _RoutineVisual(
        icon: Icons.bedtime_outlined,
        foreground: AppColors.categorySleep,
      ),
    };
  }
}

class _RoutineVisual {
  const _RoutineVisual({required this.icon, required this.foreground});

  final IconData icon;
  final Color foreground;
}
