import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../../routing/route_refresh_observer.dart';
import '../../report/models/daily_record.dart';
import '../../report/services/mock_record_service.dart';
import '../../report/services/api_record_service.dart';
import '../../report/services/record_service.dart';
import '../controllers/record_calendar_controller.dart';
import '../data/calendar_selection_store.dart';
import '../widgets/condition_calendar.dart';
import '../widgets/record_day_summary.dart';
import '../../../shared/widgets/integration_required_state.dart';

class RecordCalendarScreen extends StatefulWidget {
  const RecordCalendarScreen({super.key, required this.role, this.service});

  final AppUserRole role;
  final RecordService? service;

  @override
  State<RecordCalendarScreen> createState() => _RecordCalendarScreenState();
}

class _RecordCalendarScreenState extends State<RecordCalendarScreen>
    with RouteAware, WidgetsBindingObserver {
  late final RecordCalendarController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = RecordCalendarController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiRecordService()
              : const MockRecordService()),
      initialSelectedDate:
          CalendarSelectionStore.instance.selectedDate ??
          (AppConfig.hasSupabaseConfig ? DateTime.now() : null),
      onSelected: CalendarSelectionStore.instance.remember,
    )..addListener(_refresh);
    unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeRefreshObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => unawaited(_controller.refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_controller.refresh());
    }
  }

  @override
  void dispose() {
    routeRefreshObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isWife = widget.role == AppUserRole.wife;
    final appBar = TopAppBar(
      title: '컨디션 캘린더',
      showBack: false,
      actions: isWife ? null : _partnerActions(),
      wifeProfileAction: isWife,
      husbandMenuAction: !isWife,
    );
    final body = SafeArea(
      top: false,
      child: ContentFrame(
        child: IntegrationPreview(
          hasService: widget.service != null,
          child: _buildBody(),
        ),
      ),
    );
    if (isWife) {
      return WifeNavigationScaffold(
        currentIndex: 3,
        appBar: appBar,
        body: body,
      );
    }
    return Scaffold(appBar: appBar, body: body);
  }

  List<Widget> _partnerActions() => [
    IconButton(
      tooltip: '알림',
      onPressed: () =>
          Navigator.pushNamed(context, RouteNames.partnerNotifications),
      icon: const Icon(Icons.notifications_outlined),
    ),
  ];

  Widget _buildBody() => switch (_controller.state) {
    RecordCalendarViewState.initialLoading => const AppLoadingState(
      message: '기록을 불러오고 있어요',
    ),
    RecordCalendarViewState.error => AppErrorState(
      title: '기록을 불러오지 못했어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    RecordCalendarViewState.ready ||
    RecordCalendarViewState.refreshing => _CalendarContent(
      controller: _controller,
      role: widget.role,
      onOpenReport: _openReport,
    ),
  };

  void _openReport(DailyRecord record) {
    CalendarSelectionStore.instance.remember(record.date);
    final date = recordDateKey(record.date);
    final route = widget.role == AppUserRole.wife
        ? RouteNames.dailyReport(date)
        : RouteNames.husbandDailyReport(date);
    Navigator.pushNamed(context, route);
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.controller,
    required this.role,
    required this.onOpenReport,
  });
  final RecordCalendarController controller;
  final AppUserRole role;
  final ValueChanged<DailyRecord> onOpenReport;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedRecord;
    final month = controller.visibleMonth;
    final expandedCalendar =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    return ListView(
      key: const ValueKey('record-calendar-content'),
      padding: EdgeInsets.symmetric(
        vertical: expandedCalendar ? AppSpacing.xxl : AppSpacing.xl,
      ),
      children: [
        if (controller.state == RecordCalendarViewState.refreshing)
          const LinearProgressIndicator(
            key: ValueKey('calendar-refresh-progress'),
            minHeight: 2,
          ),
        if (controller.monthRefreshFailed)
          _CalendarRefreshError(onRetry: controller.refresh),
        const Text(
          '날짜를 선택하면 그날의 기록을 바로 확인할 수 있어요.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        SizedBox(height: expandedCalendar ? AppSpacing.xxxl : AppSpacing.xl),
        ResponsiveSplitView(
          key: const ValueKey('calendar-detail-layout'),
          primaryFlex: expandedCalendar ? 8 : 7,
          secondaryFlex: 5,
          gap: expandedCalendar ? AppSpacing.huge : AppSpacing.xxl,
          primary: _CalendarPanel(
            controller: controller,
            month: month,
            comfortable: expandedCalendar,
          ),
          secondary: selected == null
              ? const AppEmptyState(
                  title: '이 달에는 기록이 없어요',
                  message: '기록이 있는 달만 조회할 수 있어요.',
                )
              : switch (controller.detailState) {
                  RecordCalendarDetailState.error => AppErrorState(
                    title: '상세 기록을 불러오지 못했어요',
                    message: '캘린더는 그대로 이용할 수 있어요.',
                    onRetry: controller.retrySelectedDetails,
                  ),
                  RecordCalendarDetailState.empty => const AppEmptyState(
                    title: '상세 기록이 없어요',
                    message: '다른 날짜를 선택하거나 잠시 후 다시 시도해 주세요.',
                  ),
                  _ => _SelectedDayDetail(
                    record: selected,
                    role: role,
                    detailsLoading: controller.selectedDetailsLoading,
                    onOpenReport: () => onOpenReport(selected),
                  ),
                },
        ),
      ],
    );
  }

  static String _koreanDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }
}

class _CalendarRefreshError extends StatelessWidget {
  const _CalendarRefreshError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Row(
      key: const ValueKey('calendar-refresh-error'),
      children: [
        const Expanded(
          child: Text(
            '최신 기록을 불러오지 못했어요. 기존 기록을 표시합니다.',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.controller,
    required this.month,
    required this.comfortable,
  });

  final RecordCalendarController controller;
  final DateTime month;
  final bool comfortable;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('calendar-month-panel'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${month.year}년 ${month.month}월',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('calendar-previous-month'),
            tooltip: '이전 달',
            onPressed: controller.previousMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const ValueKey('calendar-next-month'),
            tooltip: '다음 달',
            onPressed: controller.canGoNext ? controller.nextMonth : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      ConditionCalendar(
        month: month,
        records: controller.records,
        selectedDate: controller.selectedDate,
        onSelected: controller.selectDate,
        comfortable: comfortable,
      ),
      SizedBox(height: comfortable ? AppSpacing.xxl : AppSpacing.xl),
      const ConditionLegend(),
    ],
  );
}

class _SelectedDayDetail extends StatelessWidget {
  const _SelectedDayDetail({
    required this.record,
    required this.role,
    required this.onOpenReport,
    this.detailsLoading = false,
  });

  final DailyRecord record;
  final AppUserRole role;
  final VoidCallback onOpenReport;
  final bool detailsLoading;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('calendar-detail-${recordDateKey(record.date)}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _CalendarContent._koreanDate(record.date),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          Text(
            '임신 ${record.pregnancyWeek}주차',
            style: const TextStyle(
              color: AppColors.primary600,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      RecordDaySummary(
        record: record,
        showMotionCaution: role == AppUserRole.wife,
        detailsLoading: detailsLoading,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        key: const ValueKey('calendar-open-report'),
        label: role == AppUserRole.wife ? '이 날 리포트 자세히 보기' : '이 날 리포트 보기',
        variant: AppButtonVariant.secondary,
        onPressed: onOpenReport,
      ),
      if (role == AppUserRole.husband &&
          DateUtils.isSameDay(record.date, DateTime.now())) ...[
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '실시간 홈캠 신체 정보 보기',
          variant: AppButtonVariant.secondary,
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.partnerMovement),
        ),
      ],
    ],
  );
}
