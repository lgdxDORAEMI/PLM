import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/empty_data_preview.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/section_header.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../condition/data/today_care_store.dart';
import '../../routine/controllers/daily_routine_controller.dart';
import '../../routine/models/daily_routine.dart';
import '../../routine/services/mock_routine_service.dart';
import '../../routine/services/routine_service.dart';
import '../../routine/widgets/routine_guide_card.dart';
import '../../routine/widgets/routine_progress.dart';
import '../../profile/data/profile_store.dart';
import '../../report/models/daily_record.dart';
import '../models/home_dashboard_data.dart';
import '../widgets/pregnancy_week_hero.dart';
import '../widgets/pregnancy_week_tip_card.dart';
import '../widgets/today_condition_summary.dart';

class WifeHomeScreen extends StatefulWidget {
  const WifeHomeScreen({super.key, this.routineService});

  final RoutineService? routineService;

  @override
  State<WifeHomeScreen> createState() => _WifeHomeScreenState();
}

class _WifeHomeScreenState extends State<WifeHomeScreen> {
  final _todayCareStore = TodayCareStore.instance;
  final _profileStore = ProfileStore.instance;
  static const _data = HomeDashboardData.mock;
  late final DailyRoutineController _routineController;

  @override
  void initState() {
    super.initState();
    _routineController = DailyRoutineController(
      service: widget.routineService ?? const MockRoutineService(),
      fallbackPlan: MockRoutineService.fallbackPlan,
    )..addListener(_refresh);
    _todayCareStore.addListener(_onTodayCareChanged);
    _profileStore.addListener(_refresh);
    if (_todayCareStore.hasTodayCare) {
      unawaited(_routineController.loadToday());
    }
  }

  @override
  void dispose() {
    _todayCareStore.removeListener(_onTodayCareChanged);
    _profileStore.removeListener(_refresh);
    _routineController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onTodayCareChanged() {
    if (_todayCareStore.hasTodayCare &&
        _routineController.state == RoutineViewState.idle) {
      unawaited(_routineController.loadToday());
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hasTodayCare = _todayCareStore.hasTodayCare;
    final pregnancyWeek =
        _profileStore.profile?.pregnancyWeekAt(DateTime.now()) ??
        _data.pregnancyWeek;
    return WifeNavigationScaffold(
      currentIndex: 0,
      appBar: TopAppBar(
        title: '홈',
        showBack: false,
        actions: [
          IconButton(
            tooltip: '메뉴',
            icon: const Icon(Icons.menu),
            onPressed: () => Navigator.pushNamed(
              context,
              RouteNames.menu(returnLocation: RouteNames.wifeHome),
            ),
          ),
        ],
      ),
      body: EmptyDataPreview(
        child: SafeArea(
          top: false,
          child: ContentFrame(
            maxWidth: 1200,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewEmpty = EmptyDataPreview.enabledOf(context);
                final effectiveHasTodayCare = hasTodayCare && !previewEmpty;
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  children: [
                    PregnancyWeekHero(
                      userName: _data.userName,
                      week: pregnancyWeek,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (constraints.maxWidth < AppBreakpoints.desktop) ...[
                      _conditionSection(effectiveHasTodayCare),
                      const SizedBox(height: AppSpacing.xxl),
                      ..._primaryContent(effectiveHasTodayCare),
                      const SizedBox(height: AppSpacing.huge),
                      _weekContext(pregnancyWeek, showData: !previewEmpty),
                    ] else
                      ResponsiveSplitView(
                        primaryFlex: 8,
                        secondaryFlex: 4,
                        gap: AppSpacing.xxl,
                        primary: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _primaryContent(effectiveHasTodayCare),
                        ),
                        secondary: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _conditionSection(effectiveHasTodayCare),
                            const SizedBox(height: AppSpacing.xxl),
                            _weekContext(
                              pregnancyWeek,
                              showData: !previewEmpty,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _conditionSection(bool hasTodayCare) => _TodayConditionSection(
    hasTodayCare: hasTodayCare,
    summary: hasTodayCare
        ? TodayConditionSummary(
            condition: _todayCareStore.today!,
            onEdit: _editCondition,
          )
        : null,
  );

  List<Widget> _primaryContent(bool hasTodayCare) =>
      hasTodayCare ? _routineContent() : _todayCarePrompt();

  Widget _weekContext(int pregnancyWeek, {required bool showData}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        title: '이번 주에 알아두세요',
        description: '임신 주차와 오늘 상태를 바탕으로 확인하는 보조 정보예요.',
      ),
      const SizedBox(height: AppSpacing.lg),
      if (showData)
        PregnancyWeekTipCard(
          week: pregnancyWeek,
          tips: pregnancyWeek == _data.pregnancyWeek
              ? _data.weekTips
              : const [
                  '임신 주수에 따라 몸의 변화가 조금씩 달라질 수 있어요.',
                  '불편함이 지속되면 진료 때 상담해 주세요.',
                ],
          caution: _data.caution,
          todayTip: _data.todayTip,
        )
      else
        Text(
          '임신 주차가 등록되면 주차별 정보가 표시돼요.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
    ],
  );

  List<Widget> _todayCarePrompt() {
    return [
      AppButton(
        key: const ValueKey('home-today-care-button'),
        label: '오늘의 컨디션 체크하러 가기',
        onPressed: () => Navigator.pushNamed(context, RouteNames.condition),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '10초면 끝나요 · 입력 후 식사·가사·건강·수면 가이드를 준비해요.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
      ),
    ];
  }

  List<Widget> _routineContent() {
    final plan = _routineController.plan;
    if (_routineController.state == RoutineViewState.loading || plan == null) {
      return const [_RoutineLoadingSection()];
    }
    return [
      Semantics(
        liveRegion: true,
        label: _routineController.isFallback ? '기본 루틴 준비 완료' : '맞춤 루틴 준비 완료',
        child: Text(
          plan.updatedLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const ValueKey('home-edit-activities'),
          onPressed: () =>
              Navigator.pushNamed(context, '${RouteNames.activity}?mode=edit'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('예정 활동 수정'),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_routineController.isFallback) ...[
        InfoBanner(
          key: const ValueKey('home-routine-fallback'),
          title: '기본 루틴을 보여드리고 있어요',
          message: '맞춤 루틴을 불러오지 못해 오늘 컨디션에 맞는 기본 가이드를 준비했어요.',
          tone: InfoBannerTone.warning,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.routineFallback),
                child: const Text('오류 안내'),
              ),
              TextButton.icon(
                key: const ValueKey('home-routine-retry'),
                onPressed: _routineController.loadToday,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      SectionHeader(
        key: const ValueKey('home-routine-success'),
        title: '오늘의 하루 루틴',
        description: '오늘 컨디션을 반영한 맞춤 가이드예요.',
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final item in plan.items) ...[
        RoutineGuideCard(
          item: item,
          onTap: () =>
              Navigator.pushNamed(context, _routeForRoutine(item.type)),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.xl),
      RoutineProgress(items: plan.items),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: '오늘의 일정 마치기',
        onPressed: () => Navigator.pushNamed(
          context,
          RouteNames.dailyReport(recordDateKey(DateTime.now())),
        ),
      ),
    ];
  }

  String _routeForRoutine(RoutineType type) {
    return switch (type) {
      RoutineType.meal => RouteNames.mealGuide,
      RoutineType.household => RouteNames.householdGuide,
      RoutineType.health => RouteNames.healthGuide,
      RoutineType.sleep => RouteNames.sleepGuide,
    };
  }

  void _editCondition() {
    Navigator.pushNamed(context, '${RouteNames.condition}?mode=edit');
  }
}

class _TodayConditionSection extends StatelessWidget {
  const _TodayConditionSection({required this.hasTodayCare, this.summary});

  final bool hasTodayCare;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(
        hasTodayCare ? 'home-condition-entered' : 'home-condition-missing',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '오늘 컨디션',
          description: hasTodayCare
              ? '저장한 상태를 오늘 루틴에 반영했어요.'
              : '아직 오늘 상태를 입력하지 않았어요.',
        ),
        if (summary != null) ...[
          const SizedBox(height: AppSpacing.lg),
          summary!,
        ],
      ],
    );
  }
}

class _RoutineLoadingSection extends StatelessWidget {
  const _RoutineLoadingSection();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '오늘의 맞춤 루틴을 만드는 중',
      child: Column(
        key: const ValueKey('home-routine-loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppLoadingState(message: '오늘의 맞춤 루틴을 만들고 있어요', compact: true),
          const SizedBox(height: AppSpacing.lg),
          Text('오늘의 하루 루틴', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          for (var index = 0; index < 4; index += 1) ...[
            const AppSkeleton(height: 96),
            if (index < 3) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
