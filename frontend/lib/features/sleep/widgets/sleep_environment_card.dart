import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/sleep_guide.dart';

class SleepEnvironmentCard extends StatelessWidget {
  const SleepEnvironmentCard({
    super.key,
    required this.setting,
    required this.onTap,
  });

  final SleepEnvironmentSetting setting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${setting.label} ${setting.value}',
      child: AppInkWell(
        key: ValueKey('sleep-environment-${setting.type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _iconBackground(setting.type),
                    foregroundColor: AppColors.categorySleep,
                    child: Icon(_icon(setting.type), size: 20),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                setting.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                setting.value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(SleepEnvironmentType type) => switch (type) {
    SleepEnvironmentType.light => Icons.lightbulb_outline,
    SleepEnvironmentType.temperature => Icons.thermostat,
    SleepEnvironmentType.humidity => Icons.water_drop_outlined,
    SleepEnvironmentType.sound => Icons.graphic_eq,
    SleepEnvironmentType.purifier => Icons.air,
  };

  Color _iconBackground(SleepEnvironmentType type) => switch (type) {
    SleepEnvironmentType.light => AppColors.warningBackground,
    SleepEnvironmentType.temperature => AppColors.dangerBackground,
    SleepEnvironmentType.humidity => AppColors.infoBackground,
    SleepEnvironmentType.sound ||
    SleepEnvironmentType.purifier => AppColors.categorySleepBackground,
  };
}
