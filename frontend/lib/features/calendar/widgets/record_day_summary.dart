import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../report/models/daily_record.dart';

class RecordDaySummary extends StatelessWidget {
  const RecordDaySummary({super.key, required this.record});
  final DailyRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryRow(label: '컨디션', value: record.conditionSummary),
        const SizedBox(height: AppSpacing.md),
        _SummaryRow(
          label: '실행한 루틴',
          value: '${record.completedRoutines} / ${record.totalRoutines} 완료',
        ),
        const SizedBox(height: AppSpacing.md),
        _SummaryRow(label: '가전 자동 실행', value: record.applianceSummary),
        if (record.burdenCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            label: '관절 부담 초과',
            value: '${record.burdenArea} ${record.burdenCount}회',
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
