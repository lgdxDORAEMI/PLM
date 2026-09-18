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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryItem(label: '컨디션', value: record.conditionSummary),
          const SizedBox(height: AppSpacing.lg),
          _SummaryItem(
            label: '실행한 루틴',
            value: '${record.completedRoutines} / ${record.totalRoutines} 완료',
          ),
          const SizedBox(height: AppSpacing.lg),
          _SummaryItem(label: '가전 자동 실행', value: record.applianceSummary),
          const SizedBox(height: AppSpacing.lg),
          _SummaryItem(
            label: '가족 분담',
            value:
                '요청 ${record.familyRequested} · 확인 ${record.familyConfirmed} · 완료 ${record.familyCompleted}',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SummaryItem(
            label: '홈캠 관련 주의사항',
            value: '장시간 서 있거나 반복적으로 숙인 행동이 확인됐어요.',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.start,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}
