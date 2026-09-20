import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/body_care_controller.dart';
import '../models/body_care_guide.dart';
import '../services/api_health_guide_service.dart';
import '../services/health_guide_service.dart';
import '../services/mock_health_guide_service.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../widgets/movement_guide_card.dart';

class HealthGuideScreen extends StatefulWidget {
  const HealthGuideScreen({super.key, this.service});

  final HealthGuideService? service;
  @override
  State<HealthGuideScreen> createState() => _HealthGuideScreenState();
}

class _HealthGuideScreenState extends State<HealthGuideScreen> {
  late final BodyCareController _controller;
  @override
  void initState() {
    super.initState();
    _controller = BodyCareController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiHealthGuideService()
              : const MockHealthGuideService()),
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
  Widget build(BuildContext context) => WifeNavigationScaffold(
    currentIndex: 0,
    allowReselect: true,
    appBar: TopAppBar(
      title: '건강 가이드',
      onBack: _handleBack,
      wifeProfileAction: true,
    ),
    body: SafeArea(
      top: false,
      child: ContentFrame(
        maxWidth: 1200,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            if (!AppConfig.hasSupabaseConfig &&
                !AppConfig.mockPreviewEnabled &&
                widget.service == null)
              const IntegrationRequiredState(),
            if (_controller.state == BodyCareViewState.loading)
              const AppLoadingState(message: '오늘의 건강 가이드를 준비하고 있어요')
            else if (_controller.state == BodyCareViewState.empty)
              const AppEmptyState(
                title: '오늘의 건강 가이드가 없어요',
                message: '오늘 루틴이 만들어지면 이곳에 표시돼요.',
              )
            else if (_controller.state != BodyCareViewState.data)
              AppErrorState(
                title: _controller.state == BodyCareViewState.authError
                    ? '로그인 상태를 확인해 주세요'
                    : '건강 가이드를 불러오지 못했어요',
                message: _controller.state == BodyCareViewState.serverError
                    ? '서버 연결을 확인한 뒤 다시 시도해 주세요.'
                    : null,
                onRetry: _controller.load,
              )
            else ...[
              ResponsiveSplitView(
                primaryFlex: 7,
                secondaryFlex: 5,
                gap: AppSpacing.xxl,
                mobileSecondaryFirst: true,
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Builder(
                      builder: (context) => Text(
                        '${_controller.selectedArea}에 맞춘 오늘의 활동',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final activity
                            in _controller.selectedActivities.indexed) ...[
                          MovementGuideCard(
                            activity: activity.$2,
                            featured: activity.$1 == 0,
                            completed: _controller.isCompleted(activity.$2.id),
                            onOpen: () => _showGuide(activity.$2),
                            onComplete: () =>
                                _controller.toggleCompleted(activity.$2.id),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        _BodyAreaSelector(
                          loads: _controller.loads,
                          selectedArea: _controller.selectedArea,
                          onSelected: _controller.selectArea,
                        ),
                      ],
                    ),
                  ],
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '오늘의 집중 부위',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      children: [
                        for (final load in _controller.loads) ...[
                          _BodyLoadCard(
                            load: load,
                            selected: load.area == _controller.selectedArea,
                            onTap: () => _controller.selectArea(load.area),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '오늘은 ${_controller.loads.map((load) => load.area).join('·')} 부위를 살펴보세요. 불편하거나 통증이 심해지면 동작을 멈추고 의료진과 상담해 주세요.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

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

class _BodyLoadCard extends StatelessWidget {
  const _BodyLoadCard({
    required this.load,
    required this.selected,
    required this.onTap,
  });
  final BodyLoad load;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${load.area} ${load.label}',
    child: AppInkWell(
      key: ValueKey('health-area-${load.area}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.categoryBody : AppColors.borderSubtle,
            width: selected ? 2 : 1,
          ),
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
      ),
    ),
  );
}

class _BodyAreaSelector extends StatelessWidget {
  const _BodyAreaSelector({
    required this.loads,
    required this.selectedArea,
    required this.onSelected,
  });

  final List<BodyLoad> loads;
  final String selectedArea;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('다른 부위 활동 보기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final load in loads)
              ChoiceChip(
                label: Text(load.area),
                selected: load.area == selectedArea,
                onSelected: (_) => onSelected(load.area),
              ),
          ],
        ),
      ],
    );
  }
}
