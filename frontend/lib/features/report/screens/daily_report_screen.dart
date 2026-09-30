import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/daily_report_controller.dart';
import '../../calendar/data/calendar_selection_store.dart';
import '../../condition/data/today_care_store.dart';
import '../models/daily_record.dart';
import '../services/mock_record_service.dart';
import '../services/api_record_service.dart';
import '../services/record_service.dart';
import '../widgets/report_metric_card.dart';
import '../widgets/routine_record_card.dart';
import '../../../shared/widgets/integration_required_state.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key, required this.date, this.service});

  final String date;
  final RecordService? service;

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  late final DailyReportController _controller;

  @override
  void initState() {
    super.initState();
    final date = _parseRouteDate(widget.date);
    _controller = DailyReportController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiRecordService()
              : const MockRecordService()),
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

  @override
  Widget build(BuildContext context) => WifeNavigationScaffold(
    currentIndex: 3,
    appBar: TopAppBar(
      title: 'Daily 리포트',
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

  /// Route의 날짜가 실제 달력 날짜와 정확히 일치하지 않으면 빈 결과로 처리한다.
  static DateTime _parseRouteDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || recordDateKey(parsed) != value) {
      return DateTime(1);
    }
    return parsed;
  }

  Widget _buildBody() => switch (_controller.state) {
    DailyReportViewState.loading => const AppLoadingState(
      message: '기록을 정리하고 있어요',
    ),
    DailyReportViewState.empty => AppEmptyState(
      title: '이 날의 기록이 없어요',
      message: '캘린더에서 기록이 있는 날짜를 선택해 주세요.',
      actionLabel: '캘린더로 이동',
      onAction: () =>
          Navigator.pushReplacementNamed(context, RouteNames.wifeCalendar),
    ),
    DailyReportViewState.error => AppErrorState(
      title: '기록을 불러오지 못했어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    _ => _DailyReportContent(
      record: _controller.record!,
      busy:
          _controller.state == DailyReportViewState.saving ||
          _controller.state == DailyReportViewState.sharing,
      onSave: _save,
      onShare: _share,
    ),
  };

  Future<void> _save() async {
    if (await _controller.save() && mounted) {
      final savedDate = _controller.record!.date;
      CalendarSelectionStore.instance.remember(savedDate);
      if (!AppConfig.hasSupabaseConfig &&
          recordDateKey(savedDate) == recordDateKey(DateTime.now())) {
        TodayCareStore.instance.finishDay();
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.wifeHome,
        (_) => false,
      );
    }
  }

  Future<void> _share() async {
    if (!await _controller.share() || !mounted) return;
    final record = _controller.record!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          size: 52,
          color: AppColors.categorySleep,
        ),
        title: const Text('남편에게 공유했어요'),
        content: Text(
          '${record.date.month}월 ${record.date.day}일 · 오늘의 기록\n남편 캘린더 탭에서 볼 수 있어요.',
        ),
        actions: [
          AppButton(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeCalendar);
    }
  }
}

class _DailyReportContent extends StatelessWidget {
  const _DailyReportContent({
    required this.record,
    required this.busy,
    required this.onSave,
    required this.onShare,
  });
  final DailyRecord record;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('daily-report-content'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    children: [
      _ReportHero(record: record),
      const SizedBox(height: AppSpacing.xl),
      Row(
        children: [
          Expanded(
            child: ReportMetricCard(
              label: '실행한 루틴',
              value: '${record.completedRoutines} / ${record.totalRoutines}',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ReportMetricCard(
              label: '가전 자동 실행',
              value: '${record.applianceCount}회',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ReportMetricCard(
              label: '가족이 완료한 일',
              value: '${record.familyCompleted}건',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xxl),
      Text('가전 자동 실행 내역', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      Text(
        record.applianceSummary,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xxl),
      ResponsiveSplitView(
        primaryFlex: 7,
        secondaryFlex: 5,
        gap: AppSpacing.xxl,
        primary: _RoutineResults(record: record),
        secondary: _ReportInsights(
          record: record,
          busy: busy,
          onSave: onSave,
          onShare: onShare,
        ),
      ),
    ],
  );
}

class _RoutineResults extends StatelessWidget {
  const _RoutineResults({required this.record});

  final DailyRecord record;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('오늘 실행한 루틴', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.lg),
      for (final routine in record.routines) ...[
        RoutineRecordCard(record: routine),
        const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _ReportInsights extends StatelessWidget {
  const _ReportInsights({
    required this.record,
    required this.busy,
    required this.onSave,
    required this.onShare,
  });

  final DailyRecord record;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('하루 인사이트', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('홈캠 관련 주의사항', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (record.motionSummaries.isEmpty)
              const Text(
                '특이 자세가 감지되지 않았어요',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              for (final summary in record.motionSummaries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    summary,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _FamilySummary(record: record),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        key: const ValueKey('report-save-button'),
        label: busy ? '처리 중…' : '저장하고 마치기',
        onPressed: busy ? null : onSave,
      ),
      const SizedBox(height: AppSpacing.md),
      AppButton(
        key: const ValueKey('report-share-button'),
        label: '남편에게 공유',
        variant: AppButtonVariant.secondary,
        onPressed: busy ? null : onShare,
      ),
    ],
  );
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.record});
  final DailyRecord record;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      // 시안: primary-600 채움 + 연한 테두리.
      color: AppColors.primary600,
      border: Border.all(color: AppColors.borderSubtle),
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 루틴을 모두 마쳤어요',
          style: TextStyle(
            color: AppColors.textInverse,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.41,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${record.date.month}월 ${record.date.day}일 · 임신 ${record.pregnancyWeek}주차',
          style: const TextStyle(
            color: AppColors.primary50,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1, color: AppColors.borderSubtle),
        const SizedBox(height: 10),
        const Text(
          '실행 기록은 내일 추천 정확도에 반영됩니다',
          style: TextStyle(
            color: AppColors.primary50,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _FamilySummary extends StatelessWidget {
  const _FamilySummary({required this.record});
  final DailyRecord record;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가족이 함께한 하루',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.info),
        ),
        const SizedBox(height: AppSpacing.lg),
        _count('요청한 집안일', record.familyRequested),
        _count('남편이 확인한 항목', record.familyConfirmed),
        _count('남편이 완료한 항목', record.familyCompleted),
        const SizedBox(height: AppSpacing.md),
        const Text('오늘도 함께해주셔서 덕분에 더 편한 하루를 보냈어요'),
      ],
    ),
  );

  Widget _count(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$count건', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
