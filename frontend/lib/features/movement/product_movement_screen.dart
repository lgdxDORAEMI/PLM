import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/app_ink_well.dart';
import '../../design_system/components/app_state_view.dart';
import '../../design_system/components/info_banner.dart';
import '../../design_system/components/content_frame.dart';
import '../../design_system/components/responsive_split_view.dart';
import '../../design_system/components/top_app_bar.dart';
import '../../design_system/components/wife_navigation_scaffold.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../routing/route_context.dart';
import '../../routing/route_names.dart';
import 'controllers/realtime_alert_controller.dart';
import 'models/movement_alert.dart';
import 'services/api_movement_dashboard_service.dart';
import 'services/mock_movement_dashboard_service.dart';
import 'services/movement_dashboard_service.dart';
import '../../shared/widgets/integration_required_state.dart';
import 'widgets/movement_alert_card.dart';

/// B-MOTION-001의 오늘 감지 상태와 로그를 Backend 조회 결과로 표시한다.
class ProductMovementScreen extends StatefulWidget {
  const ProductMovementScreen({super.key, required this.role, this.service});

  final AppUserRole role;
  final MovementDashboardService? service;

  @override
  State<ProductMovementScreen> createState() => _ProductMovementScreenState();
}

class _ProductMovementScreenState extends State<ProductMovementScreen> {
  late final RealtimeAlertController _controller;

  bool get _isWife => widget.role == AppUserRole.wife;

  @override
  void initState() {
    super.initState();
    _controller = RealtimeAlertController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiMovementDashboardService(includePrivacy: _isWife)
              : const MockMovementDashboardService()),
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
    final appBar = TopAppBar(
      title: '실시간',
      showBack: !_isWife,
      onBack: _isWife ? null : _backToPartnerCalendar,
      wifeProfileAction: _isWife,
      husbandMenuAction: !_isWife,
    );
    final body = SafeArea(
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
            if (_controller.state == MovementDashboardViewState.loading)
              const AppLoadingState(message: '오늘의 움직임 기록을 불러오고 있어요')
            else if (_controller.state != MovementDashboardViewState.data)
              AppErrorState(
                title: _controller.state == MovementDashboardViewState.authError
                    ? '움직임 기록을 볼 수 없어요'
                    : '움직임 기록을 불러오지 못했어요',
                message:
                    _controller.state == MovementDashboardViewState.serverError
                    ? '서버 연결을 확인한 뒤 다시 시도해 주세요.'
                    : null,
                onRetry: _controller.load,
              )
            else ...[
              if (_isWife) ...[
                InfoBanner(
                  title: _controller.data!.collectionEnabled
                      ? '움직임 수집 중'
                      : '움직임 수집 꺼짐',
                  message: _controller.data!.consentGranted
                      ? '움직임 데이터 수집에 동의한 상태예요.'
                      : '움직임 데이터 수집 동의가 필요해요.',
                  tone: _controller.data!.collectionEnabled
                      ? InfoBannerTone.success
                      : InfoBannerTone.info,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              ResponsiveSplitView(
                primaryFlex: 7,
                secondaryFlex: 5,
                gap: AppSpacing.xxl,
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CurrentStateCard(data: _controller.data!),
                  ],
                ),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayEventLog(events: _controller.todayAlerts),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '홈카메라는 영상을 저장하지 않고 움직임 패턴만 인식해요. 의료 진단 기능이 아닙니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
    if (_isWife) {
      return WifeNavigationScaffold(
        currentIndex: 1,
        appBar: appBar,
        body: body,
      );
    }
    return Scaffold(appBar: appBar, body: body);
  }

  void _backToPartnerCalendar() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }

}

/// 그룹 카드를 누르면 바로 뜨는 상세 목록 — 개별 항목을 또 눌러서 들어가는
/// 2차 상세 화면은 없앴다(2026-09-23 결정). 카드 자체가 이미 시각·근거·시각을
/// 다 보여주므로 여기선 그대로 나열만 한다.
Future<void> _showGroupDetail(
  BuildContext context,
  String title,
  List<MovementAlert> alerts,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '오늘 ${alerts.length}회 감지됐어요.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final alert in alerts) ...[
            MovementAlertCard(alert: alert),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text('움직임 감지 기록은 의료적 판단이나 통증 진단을 제공하지 않아요.'),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: ValueKey('movement-group-close-$title'),
            label: '닫기',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  ),
);

class _CurrentStateCard extends StatelessWidget {
  const _CurrentStateCard({required this.data});

  final MovementDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('현재 상태', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary100,
                    foregroundColor: AppColors.primary700,
                    child: Icon(Icons.accessibility_new),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '홈카메라 움직임 감지',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text('오늘의 움직임 패턴을 확인해요.'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ...[
                Row(
                  children: [
                    const Expanded(child: Text('오늘 누적 전방 굽힘 시간')),
                    Text(_durationLabel(data.forwardBendSeconds)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: (data.forwardBendSeconds / 3600).clamp(0, 1),
                  color: AppColors.warning,
                  backgroundColor: AppColors.surfaceSubtle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  data.narratives.isNotEmpty
                      ? data.narratives.first
                      : '부담 행동 ${data.burdenEventCount}건이 감지됐어요.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _durationLabel(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes분';
    return '${minutes ~/ 60}시간 ${minutes % 60}분';
  }
}

/// 같은 종류(제목 기준)의 이벤트를 "N회"로 묶어 보여준다. 눌러야 개별 내역이
/// 바텀시트로 뜬다 — 같은 부담 가능 행동이 하루에도 여러 번 개별 카드로
/// 나열되면 실제보다 위험해 보인다는 사용자 피드백(2026-09-23)에 따른 변경.
class _TodayEventLog extends StatelessWidget {
  const _TodayEventLog({required this.events});

  final List<MovementAlert> events;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MovementAlert>>{};
    for (final event in events) {
      groups.putIfAbsent(event.title, () => []).add(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('오늘 이벤트 기록', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '오늘 감지된 부담 가능 행동만 표시해요.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (groups.isEmpty)
          Text(
            '아직 감지된 이벤트가 없어요.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        for (final group in groups.entries) ...[
          _EventGroupCard(title: group.key, alerts: group.value),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _EventGroupCard extends StatelessWidget {
  const _EventGroupCard({required this.title, required this.alerts});

  final String title;
  final List<MovementAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = alertLevelStyle(alerts.first.level);
    return AppInkWell(
      key: ValueKey('movement-alert-group-$title'),
      onTap: () => _showGroupDetail(context, title, alerts),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: background,
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _representativeSuggestion(alerts),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${alerts.length}회',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 그룹 안에 서로 다른 근거(trigger_reason)가 섞여 있을 수 있어(예: "지속
  /// 부담"은 state_duration·cumulative_research_threshold 둘 다 해당), 가장
  /// 많이 나온 근거 하나를 대표로 보여준다 — report.py의 narrative 선택 방식과
  /// 동일한 원칙(Counter.most_common).
  static String _representativeSuggestion(List<MovementAlert> alerts) {
    final counts = <String, int>{};
    for (final alert in alerts) {
      counts[alert.suggestion] = (counts[alert.suggestion] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
