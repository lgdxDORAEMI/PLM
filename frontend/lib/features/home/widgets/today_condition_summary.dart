import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../condition/models/condition_draft.dart';

/// 저장된 값 중 오늘 행동 결정에 중요한 항목만 짧게 요약한다(컨디션 · 할 일 두 줄).
class TodayConditionSummary extends StatelessWidget {
  const TodayConditionSummary({
    super.key,
    required this.condition,
    required this.activities,
    required this.onEdit,
    required this.onEditActivities,
  });

  final ConditionDraft condition;
  final List<String> activities;
  final VoidCallback onEdit;
  final VoidCallback onEditActivities;

  @override
  Widget build(BuildContext context) {
    final summaries = <String>[
      '입덧 ${_discomfortLabel(condition.nausea)}',
      '피로 ${_discomfortLabel(condition.fatigue)}',
      '${_highestPainPart(condition)} 통증 ${_discomfortLabel(_highestPain(condition))}',
    ];
    return Column(
      key: const ValueKey('home-condition-complete'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 5,
      children: [
        _SummaryRow(
          label: '컨디션',
          summary: summaries.join(' · '),
          onEdit: onEdit,
        ),
        _SummaryRow(
          editKey: const ValueKey('home-edit-activities'),
          label: '할 일',
          summary: activities.isEmpty ? '예정 활동 없음' : activities.join(' · '),
          onEdit: onEditActivities,
        ),
      ],
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    this.editKey,
    required this.label,
    required this.summary,
    required this.onEdit,
  });

  final Key? editKey;
  final String label;
  final String summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.only(left: 9, right: 16),
      decoration: BoxDecoration(
        color: AppColors.disabledBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 8,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 24),
          SizedBox(
            width: 63,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '$label 수정',
            excludeSemantics: true,
            child: InkWell(
              key: editKey,
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Text(
                  '수정',
                  style: TextStyle(
                    color: AppColors.primary600,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
