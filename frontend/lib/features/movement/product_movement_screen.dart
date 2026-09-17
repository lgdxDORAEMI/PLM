import 'package:flutter/material.dart';

import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/components/content_frame.dart';
import '../../design_system/components/info_banner.dart';
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
import 'widgets/movement_alert_card.dart';

/// B-MOTION-001의 오늘 감지 상태와 로그를 서비스 교체 가능한 Mock으로 표시한다.
class ProductMovementScreen extends StatefulWidget {
  const ProductMovementScreen({super.key, required this.role});

  final AppUserRole role;

  @override
  State<ProductMovementScreen> createState() => _ProductMovementScreenState();
}

class _ProductMovementScreenState extends State<ProductMovementScreen> {
  late final RealtimeAlertController _controller;

  bool get _isWife => widget.role == AppUserRole.wife;

  @override
  void initState() {
    super.initState();
    _controller = RealtimeAlertController()..addListener(_refresh);
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
    );
    final body = SafeArea(
      top: false,
      child: ContentFrame(
        maxWidth: 1200,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            const InfoBanner(
              title: '홈카메라 활동 감지',
              message: '영상은 저장하지 않고 움직임 패턴만 인식해요. 의료 진단 기능이 아닙니다.',
              tone: InfoBannerTone.info,
              icon: Icons.videocam_outlined,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ResponsiveSplitView(
              primaryFlex: 7,
              secondaryFlex: 5,
              gap: AppSpacing.xxl,
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CurrentStateCard(
                    active: _controller.detectionEnabled,
                    onChanged: _isWife ? _controller.setDetectionEnabled : null,
                    onMoveToHousehold: _isWife ? _moveToHousehold : null,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _LatestEventSection(
                    event: _controller.latestEvent,
                    onOpen: _controller.latestEvent == null
                        ? null
                        : () => _showAlert(_controller.latestEvent!),
                  ),
                ],
              ),
              secondary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TodayEventLog(
                    events: _controller.todayAlerts,
                    onOpen: _showAlert,
                  ),
                ],
              ),
            ),
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
                  Text('추천 행동', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(alert.suggestion),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Mock 생활 패턴 안내이며 의료적 판단이나 통증 진단을 제공하지 않아요.'),
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
    required this.active,
    this.onChanged,
    required this.onMoveToHousehold,
  });

  final bool active;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onMoveToHousehold;

  @override
  Widget build(BuildContext context) => Column(
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
                        active ? '활동 감지 ON' : '활동 감지 OFF',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        active
                            ? '오늘의 움직임 패턴을 감지하고 있어요.'
                            : '새로운 감지만 중단되며 기존 기록은 유지돼요.',
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const ValueKey('movement-mock-switch'),
                  value: active,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Row(
              children: [
                Expanded(child: Text('오늘 서 있거나 움직인 시간')),
                Text('2시간 40분 / 권장 2시간'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: active ? 1 : 0,
              color: AppColors.warning,
              backgroundColor: AppColors.surfaceSubtle,
            ),
            if (active) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Text('Mock 기준으로 권장보다 40분 많아요.')),
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

class _LatestEventSection extends StatelessWidget {
  const _LatestEventSection({required this.event, required this.onOpen});

  final MovementAlert? event;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('최근 이벤트', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      if (event == null)
        const AppCard(child: Text('표시할 Mock 이벤트가 없어요.'))
      else
        MovementAlertCard(
          key: const ValueKey('movement-latest-event'),
          interactionKey: const ValueKey('movement-latest-event-open'),
          alert: event!,
          onTap: onOpen!,
        ),
    ],
  );
}

class _TodayEventLog extends StatelessWidget {
  const _TodayEventLog({required this.events, required this.onOpen});

  final List<MovementAlert> events;
  final ValueChanged<MovementAlert> onOpen;

  @override
  Widget build(BuildContext context) => Column(
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
      for (final event in events) ...[
        MovementAlertCard(alert: event, onTap: () => onOpen(event)),
        const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}

class _DeviceStateCard extends StatelessWidget {
  const _DeviceStateCard({required this.state});

  final MovementDeviceState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('기기 상태', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      AppCard(
        child: Column(
          children: [
            _DeviceRow(label: '화면 데이터', value: state.source),
            const Divider(),
            _DeviceRow(label: '홈 카메라', value: state.camera),
            const Divider(),
            _DeviceRow(label: '분석 엔진', value: state.analysis),
            const Divider(),
            _DeviceRow(label: '센서 연결', value: state.sensor),
          ],
        ),
      ),
    ],
  );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}
