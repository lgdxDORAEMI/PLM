import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/bottom_navigation.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/sleep_guide_controller.dart';
import '../models/sleep_guide.dart';
import '../services/mock_sleep_service.dart';
import '../services/sleep_service.dart';
import '../widgets/sleep_environment_card.dart';

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
    return Scaffold(
      appBar: TopAppBar(title: '수면 가이드', onBack: _handleBack),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(child: _buildBody()),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 0,
        items: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: '실시간',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '챗봇',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: '캘린더',
          ),
        ],
        onSelected: _openBottomDestination,
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
      _ => _SleepContent(
        guide: _controller.guide!,
        state: _controller.state,
        onToggle: _controller.toggleEnvironment,
        onEdit: _showSettings,
        onStart: _controller.startRoutine,
      ),
    };
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  void _openBottomDestination(int index) {
    final route = [
      RouteNames.wifeHome,
      RouteNames.wifeMovement,
      RouteNames.mealChat,
      RouteNames.wifeCalendar,
    ][index];
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _showSettings() {
    final environments = _controller.guide!.environments;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('수면 환경 설정', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '변경한 값은 이 기기의 local 상태에만 반영돼요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final item in environments) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('sleep-setting-${item.type.name}'),
                    initialValue: item.value,
                    decoration: InputDecoration(labelText: item.label),
                    items: [
                      for (final option in item.options)
                        DropdownMenuItem(value: option, child: Text(option)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _controller.updateValue(item.type, value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: '변경 완료',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepContent extends StatelessWidget {
  const _SleepContent({
    required this.guide,
    required this.state,
    required this.onToggle,
    required this.onEdit,
    required this.onStart,
  });

  final SleepGuideData guide;
  final SleepGuideViewState state;
  final ValueChanged<SleepEnvironmentType> onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final selectedCount = guide.environments
        .where((item) => item.selected)
        .length;
    final running = state == SleepGuideViewState.running;
    final completed = state == SleepGuideViewState.completed;
    return ListView(
      key: const ValueKey('sleep-guide-content'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _SleepSummary(guide: guide),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'AI가 맞춘 오늘의 수면 환경',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '선택한 항목만 실행돼요',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _EnvironmentGrid(environments: guide.environments, onToggle: onToggle),
        const SizedBox(height: AppSpacing.xxl),
        Text('오늘의 수면 팁', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        for (final tip in guide.tips) ...[
          _SleepTip(text: tip),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (completed) ...[
          InfoBanner(
            title: '$selectedCount개 환경 설정을 적용했어요',
            message: '실제 가전은 제어하지 않았으며 mock 완료 상태만 기록했어요.',
            tone: InfoBannerTone.success,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppButton(
          key: const ValueKey('sleep-start-button'),
          label: running
              ? '수면 환경 설정 중…'
              : completed
              ? '수면 루틴 시작됨'
              : '수면 루틴 시작하기',
          onPressed: running || completed || selectedCount == 0
              ? null
              : onStart,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const ValueKey('sleep-edit-button'),
          label: '설정 직접 변경하기',
          variant: AppButtonVariant.secondary,
          onPressed: running ? null : onEdit,
        ),
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
        color: AppColors.categorySleepBackground,
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
  const _EnvironmentGrid({required this.environments, required this.onToggle});
  final List<SleepEnvironmentSetting> environments;
  final ValueChanged<SleepEnvironmentType> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: environments.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: .95,
      ),
      itemBuilder: (context, index) {
        final item = environments[index];
        return SleepEnvironmentCard(
          setting: item,
          onTap: () => onToggle(item.type),
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
