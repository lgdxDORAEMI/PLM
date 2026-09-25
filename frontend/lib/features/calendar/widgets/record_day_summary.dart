import 'package:flutter/material.dart';

import '../../../design_system/components/app_state_view.dart';
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
    this.detailsLoading = false,
  });
  final DailyRecord record;
  final bool showMotionCaution;

  /// true면 [record]가 fetchMonth()의 가벼운 껍데기 값이라, 실제 값 대신
  /// 스켈레톤을 보여준다 (날짜 클릭 직후 0/0·"컨디션 기록 있음"이 잠깐
  /// 보였다가 바뀌는 깜빡임 버그 방지).
  final bool detailsLoading;

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
          _SummaryItem(
            label: '컨디션',
            value: record.conditionSummary,
            loading: detailsLoading,
          ),
          _SummaryItem(
            label: '실행한 루틴',
            value: '${record.completedRoutines} / ${record.totalRoutines} 완료',
            loading: detailsLoading,
          ),
          _SummaryItem(
            label: '가전 자동 실행',
            value: record.applianceSummary,
            loading: detailsLoading,
          ),
          _SummaryItem(
            label: '가족 분담',
            value:
                '요청 ${record.familyRequested} · 확인 ${record.familyConfirmed} · 완료 ${record.familyCompleted}',
            loading: detailsLoading,
          ),
          if (showMotionCaution)
            _SummaryItem(
              label: '홈캠 관련 주의사항',
              value: record.motionSummaries.isNotEmpty
                  ? record.motionSummaries.first
                  : '특이 자세가 감지되지 않았어요',
              loading: detailsLoading,
            ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.loading = false,
  });
  final String label;
  final String value;
  final bool loading;

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
        if (loading)
          const AppSkeleton(height: 18, width: 140, radius: 6)
        else
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
