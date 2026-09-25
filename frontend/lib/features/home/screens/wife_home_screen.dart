import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_elevation.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../condition/controllers/planned_activity_controller.dart';
import '../../condition/data/planned_activity_store.dart';
import '../../condition/data/today_care_store.dart';
import '../../condition/models/condition_draft.dart';
import '../../routine/controllers/daily_routine_controller.dart';
import '../../routine/models/daily_routine.dart';
import '../../routine/services/mock_routine_service.dart';
import '../../routine/services/api_routine_service.dart';
import '../../routine/services/routine_service.dart';
import '../../routine/widgets/routine_guide_card.dart';
import '../../routine/widgets/routine_progress.dart';
import '../../profile/data/profile_store.dart';
import '../../profile/models/profile_draft.dart';
import '../../report/models/daily_record.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../widgets/pregnancy_week_hero.dart';
import '../widgets/today_condition_summary.dart';
import '../models/home_week_context.dart';
import '../services/api_home_week_service.dart';
import '../services/home_week_service.dart';

class WifeHomeScreen extends StatefulWidget {
  const WifeHomeScreen({super.key, this.routineService, this.homeWeekService});

  final RoutineService? routineService;
  final HomeWeekService? homeWeekService;

  @override
  State<WifeHomeScreen> createState() => _WifeHomeScreenState();
}

class _WifeHomeScreenState extends State<WifeHomeScreen> {
  final _todayCareStore = TodayCareStore.instance;
  final _profileStore = ProfileStore.instance;
  final _activityStore = PlannedActivityStore.instance;
  late final DailyRoutineController _routineController;
  late final HomeWeekService? _homeWeekService;
  HomeWeekContext? _homeWeekContext;
  bool _homeWeekLoading = false;
  bool _homeWeekLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _routineController = DailyRoutineController(
      service:
          widget.routineService ??
          (AppConfig.hasSupabaseConfig
              ? ApiRoutineService()
              : const MockRoutineService()),
      fallbackPlan: widget.routineService == null
          ? null
          : MockRoutineService.fallbackPlan,
      initialPlan: widget.routineService == null && AppConfig.hasSupabaseConfig
          ? ApiRoutineService.cachedToday
          : null,
    )..addListener(_refresh);
    _homeWeekService =
        widget.homeWeekService ??
        (AppConfig.hasSupabaseConfig ? ApiHomeWeekService() : null);
    _todayCareStore.addListener(_onTodayCareChanged);
    _profileStore.addListener(_refresh);
    _activityStore.addListener(_refresh);
    // 할 일도 같은 GET /care/conditions를 쓰므로 컨디션 조회 뒤에 보낸다.
    // 동시에 보내면 BE 공유 Supabase 연결이 끊겨 503이 날 수 있다.
    unawaited(_restoreTodayCare().then((_) => _restoreActivities()));
    if (_homeWeekService != null) unawaited(_restoreHomeWeekContext());
    if (_todayCareStore.hasTodayCare || AppConfig.previewMode) {
      unawaited(_routineController.loadToday());
    }
  }

  Future<void> _restoreTodayCare() async {
    try {
      await _todayCareStore.loadToday();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 컨디션을 불러오지 못했어요.')));
    }
  }

  Future<void> _restoreActivities() async {
    try {
      await PlannedActivityController().loadActivities();
    } catch (_) {
      // 할 일 요약만 비어 보일 뿐 홈 사용에는 지장이 없다.
    }
  }

  /// 루틴 생성 전에도 프로필 주차 기반 안내를 독립적으로 복원한다.
  Future<void> _restoreHomeWeekContext() async {
    final service = _homeWeekService;
    if (service == null || _homeWeekLoading) return;
    if (mounted) {
      setState(() {
        _homeWeekLoading = true;
        _homeWeekLoadFailed = false;
      });
    }
    try {
      final context = await service.fetch();
      if (!mounted) return;
      setState(() {
        _homeWeekContext = context;
        _homeWeekLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _homeWeekLoadFailed = true;
        _homeWeekLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _todayCareStore.removeListener(_onTodayCareChanged);
    _activityStore.removeListener(_refresh);
    _profileStore.removeListener(_refresh);
    _routineController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _onTodayCareChanged() {
    if ((_todayCareStore.hasTodayCare || AppConfig.previewMode) &&
        _routineController.state == RoutineViewState.idle) {
      unawaited(_routineController.loadToday());
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final hasTodayCare = _todayCareStore.hasTodayCare || AppConfig.previewMode;
    final profileWeek =
        (_profileStore.profile ??
                (AppConfig.previewMode ? ProfileDraft.mockEdit() : null))
            ?.pregnancyWeekAt(DateTime.now());
    final pregnancyWeek = profileWeek ?? _homeWeekContext?.week;
    final plan = _routineController.plan;
    final weekNotes = plan?.weekNotes.isNotEmpty == true
        ? plan!.weekNotes
        : (_homeWeekContext?.notes ?? const <String>[]);
    final weekCaution = plan?.caution ?? _homeWeekContext?.caution;
    final hasWeekGuide = weekNotes.isNotEmpty;
    final weekStatusMessage = hasWeekGuide
        ? null
        : _homeWeekLoading
        ? '주차별 안내를 준비하고 있어요'
        : _homeWeekLoadFailed
        ? '주차별 안내를 불러오지 못했어요'
        : _homeWeekService != null
        ? '주차별 안내를 준비하지 못했어요'
        : null;
    final canRetryWeekGuide =
        !hasWeekGuide && !_homeWeekLoading && _homeWeekService != null;
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
      body: SafeArea(
        top: false,
        child: ContentFrame(
          maxWidth: 1200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final effectiveHasTodayCare = hasTodayCare;
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                children: [
                  if (pregnancyWeek == null)
                    const IntegrationRequiredState(message: '임신 주차 데이터가 없습니다.')
                  else
                    PregnancyWeekHero(
                      userName: null,
                      week: pregnancyWeek,
                      tips: weekNotes,
                      caution: weekCaution,
                      statusMessage: weekStatusMessage,
                      onRetry: canRetryWeekGuide
                          ? () => unawaited(_restoreHomeWeekContext())
                          : null,
                    ),
                  // 두 상태 시안 모두 히어로 아래 27.
                  const SizedBox(height: 27),
                  if (constraints.maxWidth < AppBreakpoints.desktop) ...[
                    _conditionSection(effectiveHasTodayCare),
                    // 입력 전: 섹션 설명 바로 아래 버튼(9). 입력 후: 섹션 간격(32).
                    SizedBox(
                      height: effectiveHasTodayCare ? AppSpacing.xxl : 9,
                    ),
                    ..._primaryContent(effectiveHasTodayCare),
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
                        children: [_conditionSection(effectiveHasTodayCare)],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _conditionSection(bool hasTodayCare) => _TodayConditionSection(
    hasTodayCare: hasTodayCare,
    summary: hasTodayCare
        ? TodayConditionSummary(
            condition: _todayCareStore.today ?? const ConditionDraft(),
            activities: _activityStore.activities,
            onEdit: _editCondition,
            onEditActivities: () => unawaited(_editActivities()),
          )
        : null,
  );

  List<Widget> _primaryContent(bool hasTodayCare) => !hasTodayCare
      ? _todayCarePrompt()
      : !AppConfig.hasSupabaseConfig &&
            !AppConfig.mockPreviewEnabled &&
            widget.routineService == null
      ? [const IntegrationRequiredState(), ..._routineContent()]
      : _routineContent();

  List<Widget> _todayCarePrompt() {
    return [
      AppButton(
        key: const ValueKey('home-today-care-button'),
        label: '오늘의 컨디션 체크하러 가기',
        onPressed: () => Navigator.pushNamed(context, RouteNames.condition),
      ),
    ];
  }

  List<Widget> _routineContent() {
    final plan = _routineController.plan;
    if (_routineController.state == RoutineViewState.error) {
      return [
        AppErrorState(
          title: '오늘의 루틴을 불러오지 못했어요',
          onRetry: _routineController.loadToday,
        ),
      ];
    }
    if (_routineController.state == RoutineViewState.loading || plan == null) {
      return const [_RoutineLoadingSection()];
    }
    return [
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
      const _SectionTitle(
        key: ValueKey('home-routine-success'),
        title: '오늘 하루 루틴',
        description: '오늘 컨디션을 반영한 맞춤 가이드를 확인해보세요.',
        descriptionStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.fromLTRB(11, 12, 10, 22),
        decoration: BoxDecoration(
          // 시안: primary-600 약 3%(0x073D7165). 반투명 위 그림자는 Flutter에서 비쳐 보여
          // surface 위에 합성한 불투명색을 쓴다.
          color: const Color(0xFFF9FAF7),
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppElevation.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final item
                in plan.homeCards.isEmpty ? plan.items : plan.homeCards)
              RoutineGuideCard(
                item: item,
                onTap: () => unawaited(_openRoutine(item.type)),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      RoutineProgress(items: plan.items),
      const SizedBox(height: AppSpacing.xl),
      // 시안: 버튼 라벨 Bold(700).
      Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
            labelLarge: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        child: AppButton(
          label: '오늘의 일정 마치기',
          onPressed: () => Navigator.pushNamed(
            context,
            RouteNames.dailyReport(
              recordDateKey(AppConfig.previewMode ? DateTime.now() : plan.date),
            ),
          ),
        ),
      ),
    ];
  }

  /// Refreshes routine_items after a detail screen changes execution state.
  Future<void> _openRoutine(RoutineType type) async {
    final plan = _routineController.plan;
    final today = DateTime.now().toUtc().add(const Duration(hours: 9));
    if (!AppConfig.previewMode &&
        (plan == null || recordDateKey(plan.date) != recordDateKey(today))) {
      await _restoreTodayCare();
      if (mounted && _todayCareStore.hasTodayCare) {
        await _routineController.loadToday(forceRefresh: true);
      }
      return;
    }
    await Navigator.pushNamed(context, _routeForRoutine(type));
    if (!mounted) return;
    await _restoreTodayCare();
    if (mounted && _todayCareStore.hasTodayCare) {
      await _routineController.loadToday(forceRefresh: true);
    }
  }

  /// Requery the routine when returning from activity editing.
  Future<void> _editActivities() async {
    await Navigator.pushNamed(context, '${RouteNames.activity}?mode=edit');
    if (mounted) {
      await _routineController.loadToday(forceRefresh: true);
    }
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
        if (hasTodayCare)
          const _SectionTitle(
            title: '컨디션 체크',
            description: '저장한 상태를 오늘 루틴에 반영했어요.',
          )
        else
          const _SectionTitle(
            title: '오늘 컨디션',
            description: '10초면 끝나요 · 입력 후 4가지 가이드를 준비해요.',
            beforeCare: true,
            descriptionStyle: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              height: 1.71,
            ),
          ),
        if (summary != null) ...[const SizedBox(height: 10), summary!],
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
          Text('오늘 하루 루틴', style: Theme.of(context).textTheme.titleLarge),
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

/// 홈 섹션 제목 + 설명. 시안상 컨디션 입력 전 화면은 제목이 Bold(700)·간격 4,
/// 입력 후 화면은 SemiBold(600)·간격 2다. 설명 스타일은 섹션마다 다르다.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    super.key,
    required this.title,
    required this.description,
    this.descriptionStyle = const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.71,
    ),
    this.beforeCare = false,
  });

  final String title;
  final String description;
  final TextStyle descriptionStyle;
  final bool beforeCare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: beforeCare ? 4 : 2,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: beforeCare ? FontWeight.w700 : FontWeight.w600,
            height: beforeCare ? 1.5 : 2,
          ),
        ),
        Text(description, style: descriptionStyle),
      ],
    );
  }
}
