import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// B-ENTRY-001의 정보 구조를 현재 PLM 디자인 시스템으로 재해석한 Demo Entry다.
class PregnancyEntryView extends StatelessWidget {
  const PregnancyEntryView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppBreakpoints.desktop;
        final intro = _EntryIntro(onStart: desktop ? onStart : null);
        const preview = _EntryPreview();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.massive),
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 7, child: intro),
                    const SizedBox(width: AppSpacing.massive),
                    const Expanded(flex: 5, child: preview),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    intro,
                    const SizedBox(height: AppSpacing.xxxl),
                    preview,
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      key: const ValueKey('entry-start-button'),
                      label: '시작하기',
                      icon: Icons.arrow_forward,
                      onPressed: onStart,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _EntryIntro extends StatelessWidget {
  const _EntryIntro({this.onStart});

  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: const SizedBox.square(
              dimension: 48,
              child: Icon(
                Icons.favorite_outline,
                color: AppColors.primary700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'PREGNANCY LIFE MODE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xxxl),
      Text(
        '오늘의 몸과 생활을\n한 흐름으로 관리해요',
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        '임신 주차와 오늘 컨디션을 바탕으로 식사·가사·건강·수면 루틴을 차분하게 이어갈 수 있어요.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
      if (onStart != null) ...[
        const SizedBox(height: AppSpacing.xxxl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: AppButton(
            key: const ValueKey('entry-start-button'),
            label: '시작하기',
            icon: Icons.arrow_forward,
            onPressed: onStart,
          ),
        ),
      ],
    ],
  );
}

class _EntryPreview extends StatelessWidget {
  const _EntryPreview();

  @override
  Widget build(BuildContext context) => AppCard(
    variant: AppCardVariant.raised,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pregnancy Life Mode', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '오늘 필요한 생활 루틴을 한눈에 확인하세요.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _EntryFeatureRow(
          icon: Icons.calendar_today_outlined,
          title: '임신 주차와 오늘 컨디션',
          description: '현재 상태를 먼저 확인해요',
        ),
        const _EntryFeatureRow(
          icon: Icons.checklist_outlined,
          title: '맞춤 하루 루틴',
          description: '필요한 일부터 차례로 이어가요',
        ),
        const _EntryFeatureRow(
          icon: Icons.restaurant_outlined,
          title: '식사·가사·건강·수면',
          description: '생활 관리 정보를 한곳에서 확인해요',
        ),
        const _EntryFeatureRow(
          icon: Icons.people_outline,
          title: '가족과 함께',
          description: '필요한 생활 업무를 나눌 수 있어요',
          showDivider: false,
        ),
      ],
    ),
  );
}

class _EntryFeatureRow extends StatelessWidget {
  const _EntryFeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary100,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(icon, color: AppColors.primary700, size: 22),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(color: AppColors.borderSubtle),
    ],
  );
}
