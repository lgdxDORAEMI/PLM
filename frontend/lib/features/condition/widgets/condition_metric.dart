import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// 5단계 상태를 색상과 Text로 함께 전달하는 Condition 전용 입력이다.
class ConditionMetric extends StatelessWidget {
  const ConditionMetric({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabels,
    required this.onChanged,
    this.positiveScale = false,
  }) : assert(valueLabels.length == 5);

  final String label;
  final int value;
  final List<String> valueLabels;
  final ValueChanged<int> onChanged;
  final bool positiveScale;

  @override
  Widget build(BuildContext context) {
    final status = valueLabels[value - 1];
    return Semantics(
      container: true,
      label: '$label, $status, 5단계 중 $value단계',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                status,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: _statusColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: List.generate(5, (index) {
              final segmentValue = index + 1;
              final selected = segmentValue <= value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == 4 ? 0 : AppSpacing.sm,
                  ),
                  child: Semantics(
                    button: true,
                    selected: segmentValue == value,
                    label: '$label ${valueLabels[index]}',
                    child: AppInkWell(
                      onTap: () => onChanged(segmentValue),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: AnimatedContainer(
                        key: ValueKey('$label-$segmentValue'),
                        duration: const Duration(milliseconds: 180),
                        height: 20,
                        decoration: BoxDecoration(
                          color: selected
                              ? _selectedColorFor(index)
                              : AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static const _moodScaleColors = [
    AppColors.primary200,
    AppColors.primary300,
    AppColors.primary400,
    AppColors.primary500,
    AppColors.primary600,
  ];

  Color _selectedColorFor(int index) {
    if (positiveScale) return _moodScaleColors[index];
    return value >= 4 ? AppColors.primary500 : AppColors.primary300;
  }

  Color get _statusColor => positiveScale
      ? _moodScaleColors[value - 1]
      : value >= 4
      ? AppColors.primary600
      : AppColors.textSecondary;
}

const discomfortLabels = ['괜찮아요', '조금 있어요', '보통이에요', '심해요', '매우 심해요'];

const moodLabels = ['많이 힘들어요', '좋지 않아요', '보통이에요', '좋아요', '아주 좋아요'];
