import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/bottom_navigation.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/section_header.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../condition/data/today_care_store.dart';
import '../../routine/controllers/daily_routine_controller.dart';
import '../../routine/models/daily_routine.dart';
import '../../routine/services/mock_routine_service.dart';
import '../../routine/services/routine_service.dart';
import '../../routine/widgets/routine_guide_card.dart';
import '../models/home_dashboard_data.dart';
import '../widgets/pregnancy_week_hero.dart';
import '../widgets/pregnancy_week_tip_card.dart';

class WifeHomeScreen extends StatefulWidget {
  const WifeHomeScreen({super.key, this.routineService});

  final RoutineService? routineService;

  @override
  State<WifeHomeScreen> createState() => _WifeHomeScreenState();
}

class _WifeHomeScreenState extends State<WifeHomeScreen> {
  final _todayCareStore = TodayCareStore.instance;
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
    if (_todayCareStore.hasTodayCare) {
      unawaited(_routineController.loadToday());
    }
  }

  @override
  void dispose() {
    _todayCareStore.removeListener(_onTodayCareChanged);
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
    return Scaffold(
      appBar: TopAppBar(
        title: '홈',
        showBack: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: '메뉴',
            icon: const Icon(Icons.menu),
            onSelected: (route) => Navigator.pushNamed(context, route),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: RouteNames.wifeProfile,
                child: Text('프로필 수정'),
              ),
              PopupMenuItem(
                value: RouteNames.wifeInvite,
                child: Text('배우자 초대'),
              ),
              PopupMenuItem(value: RouteNames.wifeSettings, child: Text('설정')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            children: [
              Text(
                '${_data.userName}님,\n오늘 임신 ${_data.pregnancyWeek}주차예요',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (hasTodayCare && _routineController.plan != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _routineController.plan!.updatedLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Center(child: PregnancyWeekHero(week: _data.pregnancyWeek)),
              const SizedBox(height: AppSpacing.xxl),
              PregnancyWeekTipCard(
                week: _data.pregnancyWeek,
                tips: _data.weekTips,
                caution: _data.caution,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (hasTodayCare) ..._routineContent() else ..._todayCarePrompt(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 0,
        items: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.sync_alt), label: '실시간'),
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

  List<Widget> _todayCarePrompt() {
    return [
      Text('오늘의 상태를 알려주세요', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '컨디션을 입력하면 오늘 몸 상태에 맞는 루틴을 준비해 드려요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        key: const ValueKey('home-today-care-button'),
        label: '오늘의 컨디션 체크하러 가기',
        onPressed: () => Navigator.pushNamed(context, RouteNames.condition),
      ),
    ];
  }

  List<Widget> _routineContent() {
    final plan = _routineController.plan;
    if (plan == null) {
      return const [AppLoadingState(message: '오늘의 루틴을 준비하고 있어요')];
    }
    return [
      if (_routineController.isFallback) ...[
        const InfoBanner(
          title: '기본 루틴을 보여드리고 있어요',
          message: '맞춤 루틴을 불러오지 못해 오늘 컨디션에 맞는 기본 가이드를 준비했어요.',
          tone: InfoBannerTone.warning,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      SectionHeader(
        title: '오늘의 하루 루틴',
        description: '오늘 컨디션을 반영한 맞춤 가이드예요.',
        actionLabel: '컨디션 다시 입력',
        onAction: () =>
            Navigator.pushNamed(context, '${RouteNames.condition}?mode=edit'),
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
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: '오늘의 일정 마치기',
        onPressed: () =>
            Navigator.pushNamed(context, RouteNames.dailyReportToday),
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

  /// Home은 목적지만 선택하고 각 Feature의 로직은 해당 Route가 담당한다.
  void _openBottomDestination(int index) {
    final route = switch (index) {
      1 => RouteNames.wifeMovement,
      2 => RouteNames.mealChat,
      3 => RouteNames.wifeCalendar,
      _ => null,
    };
    if (route != null) Navigator.pushReplacementNamed(context, route);
  }
}
