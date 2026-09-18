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
import '../../../routing/route_names.dart';
import '../../report/controllers/daily_report_controller.dart';
import '../../report/models/daily_record.dart';
import '../../report/services/mock_record_service.dart';
import '../../report/services/record_service.dart';

class PartnerMorningReportScreen extends StatefulWidget {
  const PartnerMorningReportScreen({
    super.key,
    required this.date,
    this.service,
    this.daily = false,
  });

  final String date;
  final RecordService? service;
  final bool daily;

  @override
  State<PartnerMorningReportScreen> createState() =>
      _PartnerMorningReportScreenState();
}

class _PartnerMorningReportScreenState
    extends State<PartnerMorningReportScreen> {
  late final DailyReportController _controller;

  @override
  void initState() {
    super.initState();
    final date = _parseRouteDate(widget.date);
    _controller = DailyReportController(
      service: widget.service ?? const MockRecordService(),
      date: date,
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
    body: SafeArea(top: false, child: ResponsivePageContent(child: _body())),
  );

  Widget _body() => switch (_controller.state) {
    DailyReportViewState.loading => const AppLoadingState(
      message: '아침 리포트를 불러오고 있어요',
    ),
    DailyReportViewState.empty => AppEmptyState(
      title: '공유된 리포트가 없어요',
      message: '아내가 컨디션을 입력하면 요약 리포트가 표시돼요.',
      actionLabel: '캘린더로 돌아가기',
      onAction: () =>
          Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar),
    ),
    DailyReportViewState.error => AppErrorState(
      title: '리포트를 불러오지 못했어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    _ => _PartnerReportContent(
      record: _controller.record!,
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
  const _PartnerReportContent({required this.record, required this.daily});

  final DailyRecord record;
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
              '희선님은 임신 ${record.pregnancyWeek}주차예요',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${record.date.month}월 ${record.date.day}일 컨디션 요약'),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 컨디션', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      InfoBanner(
        title: _conditionLabel(record.conditionLevel),
        message: record.conditionSummary,
        tone: record.conditionLevel == ConditionLevel.difficult
            ? InfoBannerTone.warning
            : InfoBannerTone.info,
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 예정 활동', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      const AppCard(child: Text('장보기 · 빨래 · 쓰레기 배출')),
      const SizedBox(height: AppSpacing.xl),
      Text('오늘 가이드 요약', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      const _GuideSummary(
        icon: Icons.restaurant_outlined,
        title: '식사',
        value: '속이 편한 달걀죽과 부드러운 채소',
      ),
      const SizedBox(height: AppSpacing.sm),
      const _GuideSummary(
        icon: Icons.home_outlined,
        title: '가사',
        value: '무거운 장보기는 가족과 나누기',
      ),
      const SizedBox(height: AppSpacing.sm),
      const _GuideSummary(
        icon: Icons.favorite_outline,
        title: '건강',
        value: '허리 부담을 줄이는 5분 스트레칭',
      ),
      const SizedBox(height: AppSpacing.sm),
      const _GuideSummary(
        icon: Icons.bedtime_outlined,
        title: '수면',
        value: '조명과 온도를 낮춘 수면 루틴',
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        '공유에 동의한 요약 정보만 표시됩니다.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ],
  );

  String _conditionLabel(ConditionLevel level) => switch (level) {
    ConditionLevel.good => '오늘 컨디션이 좋아요',
    ConditionLevel.normal => '오늘 컨디션은 보통이에요',
    ConditionLevel.bad => '오늘은 조금 힘든 날이에요',
    ConditionLevel.difficult => '오늘은 충분한 도움이 필요해요',
  };
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
