import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/profile_draft.dart';

class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.draft,
    required this.onEditStep,
    required this.onComplete,
    required this.completeLabel,
  });

  final ProfileDraft draft;
  final ValueChanged<int> onEditStep;
  final VoidCallback onComplete;
  final String completeLabel;

  @override
  Widget build(BuildContext context) {
    return ResponsivePageContent.form(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              title: '입력한 내용을 확인해 주세요',
              message: '출산예정일로 임신 주차가 자동 계산돼요. 언제든 수정할 수 있어요.',
              tone: InfoBannerTone.info,
            ),
            const SizedBox(height: AppSpacing.xl),
            _SummaryItem(
              label: '출산예정일 또는 마지막 생리일',
              value: _dateValue(draft),
              onTap: () => onEditStep(0),
            ),
            _SummaryItem(
              label: '신장 · 체중 (임신 전)',
              value: '${draft.height}cm · ${draft.prePregnancyWeight}kg',
              onTap: () => onEditStep(1),
            ),
            _SummaryItem(
              label: '초산 / 경산',
              value: draft.isFirstPregnancy == true ? '초산' : '경산',
              onTap: () => onEditStep(2),
            ),
            _SummaryItem(
              label: '단태 / 다태',
              value: draft.isMultiplePregnancy == true ? '다태' : '단태',
              onTap: () => onEditStep(3),
            ),
            _SummaryItem(
              label: '알레르기',
              value: _setValue(draft.allergies),
              onTap: () => onEditStep(4),
            ),
            _SummaryItem(
              label: '주의 진단 받은 것',
              value: _setValue(draft.medicalConditions),
              onTap: () => onEditStep(5),
            ),
            if (draft.medicalNote.trim().isNotEmpty)
              _SummaryItem(
                label: '그 외 들은 말',
                value: draft.medicalNote.trim(),
                onTap: () => onEditStep(5),
              ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: completeLabel, onPressed: onComplete),
            const SizedBox(height: AppSpacing.md),
            Text(
              '임신 주차가 바뀌면 루틴 기준이 자동으로 업데이트돼요.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _dateValue(ProfileDraft draft) {
    final date = draft.dueDate ?? draft.lastPeriodDate;
    if (date == null) return '입력되지 않음';
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. '
        '${date.day.toString().padLeft(2, '0')}.';
  }

  String _setValue(Set<String> values) {
    if (values.isEmpty) return '없음';
    return values.join(', ');
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: '$label, $value, 수정',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
