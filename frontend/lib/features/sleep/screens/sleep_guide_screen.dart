import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_bottom_sheet.dart';
import '../../../design_system/components/app_dialog.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../report/data/appliance_execution_store.dart';
import '../controllers/sleep_guide_controller.dart';
import '../models/sleep_guide.dart';
import '../services/mock_sleep_service.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../services/api_sleep_service.dart';
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
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiSleepService()
              : const MockSleepService()),
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
      allowReselect: true,
      appBar: TopAppBar(
        title: '수면 가이드',
        onBack: _handleBack,
        wifeProfileAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ContentFrame(
          maxWidth: 1200,
          child: IntegrationPreview(
            hasService: widget.service != null,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_controller.state) {
      SleepGuideViewState.loading => const AppLoadingState(
        message: '오늘의 수면 환경을 준비하고 있어요',
      ),
      SleepGuideViewState.empty => const AppEmptyState(
        title: '오늘의 수면 가이드가 없어요',
        message: '오늘 루틴이 만들어지면 이곳에 표시돼요.',
      ),
      SleepGuideViewState.authError => AppErrorState(
        title: '수면 가이드를 볼 수 없어요',
        message: '로그인 상태를 확인해 주세요.',
        onRetry: _controller.load,
      ),
      SleepGuideViewState.domainError ||
      SleepGuideViewState.serverError ||
      SleepGuideViewState.error => AppErrorState(
        title: '수면 가이드를 불러오지 못했어요',
        message: '잠시 후 다시 시도해 주세요.',
        onRetry: _controller.load,
      ),
      SleepGuideViewState.ready => _SleepContent(
        guide: _controller.guide!,
        onEnvironmentTap: _showEnvironmentSheet,
        onRunAll: _runAll,
      ),
    };
  }

  Future<void> _showEnvironmentSheet(SleepEnvironmentSetting setting) {
    if (setting.type == SleepEnvironmentType.purifier &&
        _controller.airPurifierConnected) {
      return showAppBottomSheet<void>(
        context: context,
        builder: (context) => SleepEnvironmentSheet(
          setting: SleepEnvironmentSetting(
            type: setting.type,
            label: setting.label,
            value: setting.value,
            options: purifierCommands.keys.toList(growable: false),
          ),
          onApply: _runAirPurifier,
        ),
      );
    }
    return showAppBottomSheet<void>(
      context: context,
      builder: (context) => SleepEnvironmentSheet(
        setting: setting,
        onApply: (value) => _controller.updateValue(setting.type, value),
      ),
    );
  }

  /// 공기청정기만 팀이 확정한 4개 라벨로 실기기를 켜고 끈다.
  Future<void> _runAirPurifier(String label) async {
    final ok = await _controller.runAirPurifier(label);
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: ok ? Icons.check_circle_outline : Icons.error_outline,
        iconColor: ok ? AppColors.success : AppColors.danger,
        title: ok ? '공기청정기를 $label(으)로 설정했어요' : '공기청정기를 제어하지 못했어요',
        content: ok
            ? const SizedBox.shrink()
            : const Text('연결 상태를 확인하고 다시 시도해 주세요.'),
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  /// 수면 환경 전체 실행을 한 번의 이력으로 남기고 팝업으로 안내한다.
  Future<void> _runAll() async {
    if (_controller.state != SleepGuideViewState.ready) return;
    ApplianceExecutionStore.instance.record(
      source: ApplianceExecutionSource.sleep,
      label: '수면 환경 전체 실행',
    );
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.nightlight_round,
        iconColor: AppColors.categorySleep,
        title: '수면 루틴을 실행했습니다',
        message: '수면 환경 전체 실행 1회를 오늘의 가전 실행 내역에 반영했어요.',
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
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
  const _SleepContent({
    required this.guide,
    required this.onEnvironmentTap,
    required this.onRunAll,
  });

  final SleepGuideData guide;
  final ValueChanged<SleepEnvironmentSetting> onEnvironmentTap;
  final VoidCallback onRunAll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('sleep-guide-content'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _SleepSummary(guide: guide),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: Text(
                'AI가 맞춘 오늘의 수면 환경',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            IconButton.filled(
              key: const ValueKey('sleep-run-all-button'),
              tooltip: '수면 환경 전체 실행',
              onPressed: onRunAll,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.categorySleep,
                foregroundColor: AppColors.textInverse,
                // 최소 터치 영역(44)까지만 줄인다.
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _EnvironmentGrid(
          environments: guide.environments,
          onTap: onEnvironmentTap,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('오늘의 수면 팁', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Column(
          children: [
            for (final tip in guide.tips) ...[
              _SleepTip(text: tip),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
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
        // 시안: 수면 색 40% 채움 + 연한 테두리.
        color: AppColors.categorySleep.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.summaryTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.41,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            guide.summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 17,
              height: 1.59,
            ),
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
                const Expanded(
                  child: Text(
                    '권장 취침 시간',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const Icon(
                  Icons.nightlight_round,
                  size: 22,
                  color: AppColors.categorySleep,
                ),
                const SizedBox(width: 9),
                Text(
                  guide.recommendedBedtime,
                  style: const TextStyle(
                    color: AppColors.categorySleep,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
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
