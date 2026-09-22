import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../core/config/app_config.dart';
import '../../../routing/route_names.dart';
import '../../../routing/route_refresh_observer.dart';
import '../../report/models/daily_record.dart';
import '../controllers/partner_morning_report_controller.dart';
import '../models/partner_morning_report.dart';
import '../services/api_partner_morning_report_service.dart';
import '../services/mock_partner_morning_report_service.dart';
import '../services/partner_morning_report_service.dart';
import '../../../shared/widgets/integration_required_state.dart';

class PartnerMorningReportScreen extends StatefulWidget {
  const PartnerMorningReportScreen({
    super.key,
    required this.date,
    this.service,
    this.daily = false,
  });

  final String date;
  final PartnerMorningReportService? service;
  final bool daily;

  @override
  State<PartnerMorningReportScreen> createState() =>
      _PartnerMorningReportScreenState();
}

class _PartnerMorningReportScreenState extends State<PartnerMorningReportScreen>
    with RouteAware, WidgetsBindingObserver {
  late final PartnerMorningReportController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final date = _parseRouteDate(widget.date);
    _controller = PartnerMorningReportController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiPartnerMorningReportService()
              : const MockPartnerMorningReportService()),
      date: date,
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
  void didPopNext() => unawaited(_controller.load());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_controller.load());
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

  /// 잘못된 날짜 parameter가 오늘 데이터로 조용히 대체되지 않도록 검증한다.
  static DateTime _parseRouteDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || recordDateKey(parsed) != value) return DateTime(1);
    return parsed;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(
      title: widget.daily ? 'Daily 리포트' : '오전 리포트',
      onBack: _handleBack,
      husbandMenuAction: true,
      actions: [
        IconButton(
          tooltip: '알림',
          onPressed: () =>
              Navigator.pushNamed(context, RouteNames.partnerNotifications),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: IntegrationPreview(
          hasService: widget.service != null,
          child: _body(),
        ),
      ),
    ),
  );

  Widget _body() => switch (_controller.state) {
    PartnerMorningReportState.loading => const AppLoadingState(
      message: '아침 리포트를 불러오고 있어요',
    ),
    PartnerMorningReportState.empty => AppEmptyState(
      title: widget.date == recordDateKey(DateTime.now())
          ? '오늘 컨디션이 아직 등록되지 않았어요.'
          : '이 날짜의 리포트가 없어요.',
      message: '아내가 컨디션을 입력하면 요약 리포트가 표시돼요.',
      actionLabel: '캘린더로 돌아가기',
      onAction: () =>
          Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar),
    ),
    PartnerMorningReportState.authError => AppErrorState(
      title: '리포트를 볼 수 없어요',
      message: '로그인 상태와 배우자 연결 권한을 확인해 주세요.',
      onRetry: _controller.load,
    ),
    PartnerMorningReportState.serverError => AppErrorState(
      title: '서버에 연결할 수 없어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    PartnerMorningReportState.error => AppErrorState(
      title: '리포트를 불러오지 못했어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    _ => _PartnerReportContent(
      report: _controller.report!,
      daily: widget.daily,
    ),
  };

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }
}

class _PartnerReportContent extends StatelessWidget {
  const _PartnerReportContent({required this.report, required this.daily});

  final PartnerMorningReport report;
  final bool daily;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('partner-morning-report'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBadge(
              label: daily ? '하루 기록' : '오늘 아침',
              tone: AppBadgeTone.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '임신 ${report.pregnancyWeek}주차예요',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${report.targetDate.month}월 ${report.targetDate.day}일 컨디션 요약',
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 컨디션', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      InfoBanner(
        title: '오늘 컨디션 요약',
        message: report.conditionSummary.isEmpty
            ? '공유된 컨디션 요약이 없어요.'
            : report.conditionSummary.join(' · '),
        tone: InfoBannerTone.info,
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 예정 활동', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      AppCard(
        child: Text(
          report.plannedActivities.isEmpty
              ? '공유된 예정 활동이 없어요.'
              : report.plannedActivities.join(' · '),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 가이드 요약', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      if (report.guideSummaries.isEmpty)
        const AppCard(child: Text('공유된 가이드 요약이 없어요.'))
      else
        for (final guide in _guideItems.indexed) ...[
          _GuideSummary(
            icon: guide.$2.icon,
            title: guide.$2.label,
            value: guide.$2.value,
          ),
          if (guide.$1 < _guideItems.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      const SizedBox(height: AppSpacing.md),
      const Text(
        '공유에 동의한 요약 정보만 표시됩니다.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ],
  );

  List<_GuideItem> get _guideItems => [
    if (report.guideSummaries['meal'] case final value?)
      _GuideItem(Icons.restaurant_outlined, '식사', value),
    if (report.guideSummaries['household'] case final value?)
      _GuideItem(Icons.home_outlined, '가사', value),
    if (report.guideSummaries['health'] case final value?)
      _GuideItem(Icons.favorite_outline, '건강', value),
    if (report.guideSummaries['sleep'] case final value?)
      _GuideItem(Icons.bedtime_outlined, '수면', value),
  ];
}

class _GuideItem {
  const _GuideItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _GuideSummary extends StatelessWidget {
  const _GuideSummary({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary600),
        const SizedBox(width: AppSpacing.md),
        SizedBox(width: 44, child: Text(title)),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    ),
  );
}
