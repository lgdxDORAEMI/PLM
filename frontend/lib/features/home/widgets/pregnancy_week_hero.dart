import 'package:flutter/material.dart';

import '../../../design_system/components/hero_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// Home의 첫 맥락을 장식보다 정보 위계 중심으로 전달한다.
class PregnancyWeekHero extends StatelessWidget {
  const PregnancyWeekHero({
    super.key,
    required this.userName,
    required this.week,
    this.tips = const [],
    this.caution,
    this.statusMessage,
    this.onRetry,
  });

  final String? userName;
  final int week;
  final List<String> tips;
  final String? caution;
  final String? statusMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('home-week-hero'),
      container: true,
      label: userName == null ? '현재 임신 $week주차' : '$userName님, 현재 임신 $week주차',
      child: HeroCard(
        title: tips.isEmpty ? '임신 $week주차' : '$week주차에는 이런 시기예요',
        description: tips.isEmpty
            ? statusMessage ?? '오늘의 상태부터 확인하고, 필요한 일만 차분히 이어가요.'
            : null,
        content: tips.isEmpty
            ? onRetry == null
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textInverse,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 불러오기'),
                      ),
                    )
            : _WeekGuideContent(tips: tips, caution: caution),
      ),
    );
  }
}

class _WeekGuideContent extends StatelessWidget {
  const _WeekGuideContent({required this.tips, required this.caution});

  final List<String> tips;
  final String? caution;

  @override
  Widget build(BuildContext context) {
    final caution = this.caution?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: AppColors.primary100,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        color: AppColors.textInverse,
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (caution.isNotEmpty) ...[
            const Divider(color: AppColors.primary200),
            const SizedBox(height: AppSpacing.sm),
            Text(
              caution,
              style: const TextStyle(
                color: AppColors.primary50,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
