import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_elevation.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../report/models/daily_record.dart';

class RecordDaySummary extends StatelessWidget {
  const RecordDaySummary({
    super.key,
    required this.record,
    required this.showMotionCaution,
  });
  final DailyRecord record;
  final bool showMotionCaution;

  @override
  Widget build(BuildContext context) {
    // 시안: 따뜻한 배경 카드 + level1 그림자, 항목 간격 26.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.accentWarmBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 26,
        children: [
          _SummaryItem(label: '컨디션', value: record.conditionSummary),
          _SummaryItem(
            label: '실행한 루틴',
            value: '${record.completedRoutines} / ${record.totalRoutines} 완료',
          ),
          _SummaryItem(label: '가전 자동 실행', value: record.applianceSummary),
          _SummaryItem(
            label: '가족 분담',
            value:
                '요청 ${record.familyRequested} · 확인 ${record.familyConfirmed} · 완료 ${record.familyCompleted}',
          ),
          if (showMotionCaution)
            _SummaryItem(
              label: '홈캠 관련 주의사항',
              value: record.motionSummaries.isNotEmpty
                  ? record.motionSummaries.first
                  : '특이 자세가 감지되지 않았어요',
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textAlign: TextAlign.start,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
