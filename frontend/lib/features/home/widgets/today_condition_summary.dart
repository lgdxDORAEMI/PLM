import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../condition/models/condition_draft.dart';

/// 저장된 값 중 오늘 행동 결정에 중요한 항목만 짧게 요약한다.
class TodayConditionSummary extends StatelessWidget {
  const TodayConditionSummary({
    super.key,
    required this.condition,
    required this.onEdit,
  });

  final ConditionDraft condition;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final summaries = <String>[
      '입덧 ${_discomfortLabel(condition.nausea)}',
      '피로 ${_discomfortLabel(condition.fatigue)}',
      '${_highestPainPart(condition)} 통증 ${_discomfortLabel(_highestPain(condition))}',
    ];
    return DecoratedBox(
      key: const ValueKey('home-condition-complete'),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 컨디션 입력 완료',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    summaries.join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('수정')),
          ],
        ),
      ),
    );
  }

  static String _discomfortLabel(int value) => switch (value) {
    <= 1 => '괜찮음',
    2 => '조금',
    3 => '보통',
    _ => '심함',
  };

  static int _highestPain(ConditionDraft value) => [
    value.waistPain,
    value.pelvisPain,
    value.legPain,
    value.wristPain,
  ].reduce((current, next) => current >= next ? current : next);

  static String _highestPainPart(ConditionDraft value) {
    final painByPart = <String, int>{
      '허리': value.waistPain,
      '골반': value.pelvisPain,
      '다리': value.legPain,
      '손목': value.wristPain,
    };
    return painByPart.entries
        .reduce((current, next) => current.value >= next.value ? current : next)
        .key;
  }
}
