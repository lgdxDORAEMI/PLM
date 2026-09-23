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
import '../widgets/youtube_embed.dart';

class HealthGuideScreen extends StatefulWidget {
  const HealthGuideScreen({super.key, this.service});

  final HealthGuideService? service;
  @override
  State<HealthGuideScreen> createState() => _HealthGuideScreenState();
}

class _HealthGuideScreenState extends State<HealthGuideScreen> {
  late final BodyCareController _controller;
  bool _showFocusHelp = false;
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
                          areas: _controller.availableAreas,
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
                    Row(
                      children: [
                        Text(
                          '오늘의 집중 부위',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Semantics(
                          button: true,
                          label: '오늘의 집중 부위 도움말',
                          child: AppInkWell(
                            key: const ValueKey('health-focus-help-button'),
                            onTap: () => setState(
                              () => _showFocusHelp = !_showFocusHelp,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(AppSpacing.xs),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    AppColors.categoryHealthBackground,
                                foregroundColor: AppColors.categoryHealth,
                                child: Icon(Icons.question_mark, size: 15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _showFocusHelp
                          ? Padding(
                              key: const ValueKey('health-focus-help-bubble'),
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: AppInkWell(
                                onTap: () =>
                                    setState(() => _showFocusHelp = false),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.input,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    border: Border.all(
                                      color: AppColors.primary200,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.input,
                                    ),
                                  ),
                                  child: const Text(
                                    '컨디션 정보를 반영하여 통증이 보통 이상인 항목을 보여줍니다.',
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_controller.loads.isEmpty)
                      const Text('오늘 입력한 통증 중 보통 이상인 부위가 없어요.')
                    else
                      Column(
                        children: [
                          for (final load in _controller.loads) ...[
                            _BodyLoadCard(
                              load: load,
                              selected: load.area == _controller.selectedArea,
                              onTap: () => _openAreaGuide(load.area),
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
                _controller.loads.isEmpty
                    ? '불편하거나 통증이 생기면 동작을 멈추고 의료진과 상담해 주세요.'
                    : '오늘은 ${_controller.loads.map((load) => load.area).join('·')} 부위를 살펴보세요. 불편하거나 통증이 심해지면 동작을 멈추고 의료진과 상담해 주세요.',
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

  /// 집중 부위 카드에서도 부위 선택과 대표 운동 재생을 한 번에 수행한다.
  void _openAreaGuide(String area) {
    _controller.selectArea(area);
    final activities = _controller.activities.where(
      (activity) => activity.area == area,
    );
    if (activities.isNotEmpty) {
      unawaited(_showGuide(activities.first));
    }
  }

  Future<void> _showGuide(BodyCareActivity activity) {
    final video = activity.video;
    if (video != null && video.canEmbed) {
      return _showVideo(activity, video);
    }
    return showModalBottomSheet<void>(
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

  Future<void> _showVideo(
    BodyCareActivity activity,
    HealthExerciseVideo video,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          video.provider,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (video.duration != null || video.target != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            [?video.duration, ?video.target].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.categoryHealth),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YouTubeEmbed(youtubeId: video.youtubeId),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: ValueKey('health-video-complete-${activity.id}'),
                onPressed: () {
                  _controller.toggleCompleted(activity.id);
                  Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.check),
                label: const Text('활동 완료'),
              ),
            ],
          ),
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
    required this.areas,
    required this.selectedArea,
    required this.onSelected,
  });

  final List<String> areas;
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
            for (final area in areas)
              ChoiceChip(
                label: Text(area),
                selected: area == selectedArea,
                onSelected: (_) => onSelected(area),
              ),
          ],
        ),
      ],
    );
  }
}
