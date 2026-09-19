import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
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
  bool _showAllEvents = false;

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
              const IntegrationRequiredState(message: '움직임 데이터가 없습니다.')
            else ...[
              if (_controller.state == MovementDashboardViewState.loading)
                const AppLoadingState(message: '오늘의 움직임 기록을 불러오고 있어요')
              else if (_controller.state != MovementDashboardViewState.data)
                AppErrorState(
                  title:
                      _controller.state == MovementDashboardViewState.authError
                      ? '움직임 기록을 볼 수 없어요'
                      : '움직임 기록을 불러오지 못했어요',
                  message:
                      _controller.state ==
                          MovementDashboardViewState.serverError
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
                      _CurrentStateCard(
                        data: _controller.data!,
                        onMoveToHousehold: _isWife ? _moveToHousehold : null,
                      ),
                    ],
                  ),
                  secondary: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayEventLog(
                        events: _controller.todayAlerts,
                        showAll: _showAllEvents,
                        onShowAll: () => setState(() => _showAllEvents = true),
                        onOpen: _showAlert,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '홈카메라는 영상을 저장하지 않고 움직임 패턴만 인식해요. 의료 진단 기능이 아닙니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
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

  void _moveToHousehold() =>
      Navigator.pushNamed(context, RouteNames.householdGuide);

  void _backToPartnerCalendar() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }

  Future<void> _showAlert(MovementAlert alert) => showModalBottomSheet<void>(
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
            Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(alert.description),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warningBackground,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('감지 근거', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(alert.suggestion),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('움직임 감지 기록은 의료적 판단이나 통증 진단을 제공하지 않아요.'),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: ValueKey('movement-alert-close-${alert.id}'),
              label: '닫기',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CurrentStateCard extends StatelessWidget {
  const _CurrentStateCard({
    required this.data,
    required this.onMoveToHousehold,
  });

  final MovementDashboardData data;
  final VoidCallback? onMoveToHousehold;

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.narratives.isNotEmpty
                            ? data.narratives.first
                            : '부담 행동 ${data.burdenEventCount}건이 감지됐어요.',
                      ),
                    ),
                    if (onMoveToHousehold != null)
                      OutlinedButton(
                        key: const ValueKey('movement-to-household'),
                        onPressed: onMoveToHousehold,
                        child: const Text('가전으로 옮기기'),
                      ),
                  ],
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

class _TodayEventLog extends StatelessWidget {
  const _TodayEventLog({
    required this.events,
    required this.showAll,
    required this.onShowAll,
    required this.onOpen,
  });

  final List<MovementAlert> events;
  final bool showAll;
  final VoidCallback onShowAll;
  final ValueChanged<MovementAlert> onOpen;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events;
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
        if (visibleEvents.isEmpty)
          Text(
            '아직 감지된 이벤트가 없어요.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        for (final event
            in (showAll ? visibleEvents : visibleEvents.take(3))) ...[
          MovementAlertCard(alert: event, onTap: () => onOpen(event)),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!showAll && visibleEvents.length > 3)
          TextButton.icon(
            key: const ValueKey('movement-show-all-events'),
            onPressed: onShowAll,
            icon: const Icon(Icons.expand_more),
            label: Text('더보기 (${visibleEvents.length - 3})'),
          ),
      ],
    );
  }
}
