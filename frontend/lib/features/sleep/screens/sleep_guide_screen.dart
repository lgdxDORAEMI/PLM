import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_bottom_sheet.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/sleep_guide_controller.dart';
import '../models/sleep_guide.dart';
import '../services/mock_sleep_service.dart';
import '../services/sleep_service.dart';
import '../widgets/sleep_environment_card.dart';
import '../widgets/sleep_environment_sheet.dart';

class SleepGuideScreen extends StatefulWidget {
  const SleepGuideScreen({super.key, this.service});

  final SleepService? service;

  @override
  State<SleepGuideScreen> createState() => _SleepGuideScreenState();
}

class _SleepGuideScreenState extends State<SleepGuideScreen> {
  late final SleepGuideController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SleepGuideController(
      service: widget.service ?? const MockSleepService(),
    )..addListener(_refresh);
    unawaited(_controller.load());
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
  Widget build(BuildContext context) {
    return WifeNavigationScaffold(
      currentIndex: 0,
      appBar: TopAppBar(
        title: '수면 가이드',
        onBack: _handleBack,
        wifeProfileAction: true,
        actions: [
          IconButton(
            key: const ValueKey('sleep-run-all-button'),
            tooltip: '수면 환경 전체 실행',
            onPressed: _runAll,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentFrame(maxWidth: 1200, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_controller.state) {
      SleepGuideViewState.loading => const AppLoadingState(
        message: '오늘의 수면 환경을 준비하고 있어요',
      ),
      SleepGuideViewState.error => AppErrorState(
        title: '수면 가이드를 불러오지 못했어요',
        message: '잠시 후 다시 시도해 주세요.',
        onRetry: _controller.load,
      ),
      SleepGuideViewState.ready => _SleepContent(
        guide: _controller.guide!,
        onEnvironmentTap: _showEnvironmentSheet,
      ),
    };
  }

  Future<void> _showEnvironmentSheet(SleepEnvironmentSetting setting) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (context) => SleepEnvironmentSheet(
        setting: setting,
        onApply: (value) => _controller.updateValue(setting.type, value),
      ),
    );
  }

  /// 현재 추천된 수면 환경 전체 실행 요청을 사용자에게 즉시 확인시킨다.
  void _runAll() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('추천 수면 환경 전체 실행을 시작했어요.')));
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }
}

class _SleepContent extends StatelessWidget {
  const _SleepContent({required this.guide, required this.onEnvironmentTap});

  final SleepGuideData guide;
  final ValueChanged<SleepEnvironmentSetting> onEnvironmentTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('sleep-guide-content'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _SleepSummary(guide: guide),
        const SizedBox(height: AppSpacing.xxl),
        Text('AI가 맞춘 오늘의 수면 환경', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        _EnvironmentGrid(
          environments: guide.environments,
          onTap: onEnvironmentTap,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('오늘의 수면 팁', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        for (final tip in guide.tips) ...[
          _SleepTip(text: tip),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SleepSummary extends StatelessWidget {
  const _SleepSummary({required this.guide});

  final SleepGuideData guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.pageMobile),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  guide.summaryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Icon(
                Icons.nightlight_round,
                color: AppColors.categorySleep,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            guide.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('권장 취침 시간')),
                Text(
                  guide.recommendedBedtime,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.categorySleep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentGrid extends StatelessWidget {
  const _EnvironmentGrid({required this.environments, required this.onTap});

  final List<SleepEnvironmentSetting> environments;
  final ValueChanged<SleepEnvironmentSetting> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final item in environments)
              SizedBox(
                width: itemWidth,
                child: SleepEnvironmentCard(
                  setting: item,
                  onTap: () => onTap(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SleepTip extends StatelessWidget {
  const _SleepTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.categorySleep),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text)),
      ],
    );
  }
}
