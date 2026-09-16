import 'package:flutter/material.dart';

import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../controllers/body_care_controller.dart';
import '../models/body_care_guide.dart';
import '../widgets/movement_guide_card.dart';

class HealthGuideScreen extends StatefulWidget {
  const HealthGuideScreen({super.key});
  @override
  State<HealthGuideScreen> createState() => _HealthGuideScreenState();
}

class _HealthGuideScreenState extends State<HealthGuideScreen> {
  late final BodyCareController _controller;
  @override
  void initState() {
    super.initState();
    _controller = BodyCareController()..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopAppBar(title: '건강 가이드'),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            const _BodySummary(),
            const SizedBox(height: AppSpacing.xxl),
            Text('오늘의 집중 부위', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            for (final load in BodyCareMockData.loads) ...[
              _BodyLoadCard(load: load),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              '허리에 맞춘 오늘의 활동',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final activity in BodyCareMockData.activities) ...[
              MovementGuideCard(
                activity: activity,
                completed: _controller.isCompleted(activity.id),
                onOpen: () => _showGuide(activity),
                onComplete: () => _controller.toggleCompleted(activity.id),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '불편하거나 통증이 심해지면 동작을 멈추고 의료진과 상담해 주세요.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showGuide(BodyCareActivity activity) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(activity.guide),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () {
                    _controller.toggleCompleted(activity.id);
                    Navigator.pop(context);
                  },
                  child: const Text('활동 완료'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _BodySummary extends StatelessWidget {
  const _BodySummary();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      color: AppColors.categoryBodyBackground,
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘은 허리·골반이 가장 힘든 날',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.categoryBody),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('28주차에 자주 나타나는 치골결합통 구간이고, 오늘 컨디션에서 허리 부담을 높게 표시했어요.'),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        Text(
          '임신 주차 · 오늘 컨디션 체크를 함께 반영',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
      ],
    ),
  );
}

class _BodyLoadCard extends StatelessWidget {
  const _BodyLoadCard({required this.load});
  final BodyLoad load;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.categoryBodyBackground,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                load.area,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              load.label,
              style: const TextStyle(color: AppColors.categoryBody),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: load.value,
          color: AppColors.categoryBody,
          backgroundColor: AppColors.surface,
        ),
      ],
    ),
  );
}
