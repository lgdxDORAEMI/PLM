import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
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
      selected: setting.selected,
      label: '${setting.label} ${setting.value}',
      child: InkWell(
        key: ValueKey('sleep-environment-${setting.type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: setting.selected
                ? AppColors.categorySleepBackground
                : AppColors.surface,
            border: Border.all(
              color: setting.selected
                  ? AppColors.categorySleep
                  : AppColors.borderSubtle,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    setting.selected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: setting.selected
                        ? AppColors.categorySleep
                        : AppColors.borderStrong,
                  ),
                  const Spacer(),
                  CircleAvatar(
                    backgroundColor: _iconBackground(setting.type),
                    foregroundColor: AppColors.categorySleep,
                    child: Icon(_icon(setting.type), size: 20),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                setting.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                setting.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
