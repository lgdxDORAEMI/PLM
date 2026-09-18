import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../controllers/app_text_scale_store.dart';
import '../models/app_font_size.dart';

class FontSizeSelector extends StatelessWidget {
  const FontSizeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppTextScaleStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('글자 크기', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '앱 전체 화면의 글자 크기를 조정합니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - AppSpacing.sm * 2) / 3;
              return Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final option in AppFontSize.values)
                    SizedBox(
                      width: itemWidth,
                      child: ChoiceChip(
                        key: ValueKey('font-size-${option.name}'),
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            option.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: store.value == option,
                        showCheckmark: false,
                        onSelected: (_) => store.update(option),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppCard(child: Text('선택한 크기로 표시되는 글자 예시입니다.')),
          const SizedBox(height: AppSpacing.md),
          Text(
            '기기의 접근성 글자 확대 설정도 함께 적용됩니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
