import 'package:flutter/material.dart';

import '../../design_system/components/app_button.dart';
import '../../design_system/components/bottom_navigation.dart';
import '../../design_system/components/responsive_page_content.dart';
import '../../design_system/components/top_app_bar.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../routing/route_context.dart';
import '../../routing/route_names.dart';
import 'controllers/realtime_alert_controller.dart';
import 'models/movement_alert.dart';
import 'widgets/movement_alert_card.dart';

class ProductMovementScreen extends StatefulWidget {
  const ProductMovementScreen({super.key, required this.role});
  final AppUserRole role;
  @override
  State<ProductMovementScreen> createState() => _ProductMovementScreenState();
}

class _ProductMovementScreenState extends State<ProductMovementScreen> {
  late final RealtimeAlertController _controller;

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
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopAppBar(title: '실시간', showBack: false),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            _MonitoringSummary(
              monitoring: _controller.monitoring,
              onChanged: _controller.setMonitoring,
              onMoveToHome: widget.role == AppUserRole.wife
                  ? _moveToHousehold
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '영상은 저장하지 않고 움직임 패턴만 표시하는 mock 화면이에요.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary600,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('누적 알림 내역이에요'),
                        Text('표시된 내용은 진단이 아닌 생활 패턴 안내예요'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final alert in _controller.alerts) ...[
              MovementAlertCard(
                alert: alert,
                reviewed: _controller.isReviewed(alert.id),
                onTap: () => _showAlert(alert),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    ),
    bottomNavigationBar: widget.role == AppUserRole.wife
        ? _WifeMovementNavigation(onSelected: _openWifeTab)
        : _PartnerMovementNavigation(onSelected: _openPartnerTab),
  );

  void _moveToHousehold() {
    if (widget.role == AppUserRole.wife) {
      Navigator.pushNamed(context, RouteNames.householdGuide);
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
            Row(
              children: [
                Icon(
                  alert.level == MovementAlertLevel.high
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  color: alert.level == MovementAlertLevel.high
                      ? AppColors.danger
                      : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  alert.level == MovementAlertLevel.high ? '높은 주의' : '주의',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(alert.description),
            const SizedBox(height: AppSpacing.sm),
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
            const Text('이 정보는 의료적 판단이나 통증 진단을 제공하지 않아요.'),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: ValueKey('movement-alert-confirm-${alert.id}'),
              label: _controller.isReviewed(alert.id) ? '확인했어요' : '확인',
              onPressed: () {
                _controller.acknowledge(alert.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _openWifeTab(int index) => Navigator.pushReplacementNamed(
    context,
    [
      RouteNames.wifeHome,
      RouteNames.wifeMovement,
      RouteNames.mealChat,
      RouteNames.wifeCalendar,
    ][index],
  );
  void _openPartnerTab(int index) => Navigator.pushReplacementNamed(
    context,
    [RouteNames.partnerCalendar, RouteNames.partnerMovement][index],
  );
}

class _MonitoringSummary extends StatelessWidget {
  const _MonitoringSummary({
    required this.monitoring,
    required this.onChanged,
    required this.onMoveToHome,
  });
  final bool monitoring;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onMoveToHome;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      color: monitoring ? AppColors.successBackground : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadius.hero),
      border: Border.all(color: AppColors.success.withValues(alpha: .2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: monitoring
                  ? AppColors.success
                  : AppColors.textTertiary,
              foregroundColor: Colors.white,
              child: Icon(Icons.camera_indoor_outlined),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('홈 카메라 움직임 감지'),
                  Text(
                    monitoring ? '가전 내장 카메라 · mock 인식 중' : 'mock 감지가 꺼져 있어요',
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('movement-monitoring-switch'),
              value: monitoring,
              onChanged: onChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(child: Text('오늘 서 있거나 움직인 시간')),
            Text(monitoring ? '2시간 40분 / 권장 2시간' : '감지 중지됨'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: monitoring ? .8 : 0,
          color: AppColors.success,
          backgroundColor: AppColors.warningBackground,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                monitoring ? '권장보다 40분 더 움직이셨어요' : '이전에 확인한 기록은 유지돼요',
              ),
            ),
            if (onMoveToHome != null)
              OutlinedButton(
                key: const ValueKey('movement-to-household'),
                onPressed: onMoveToHome,
                child: const Text('가전으로 옮기기'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _WifeMovementNavigation extends StatelessWidget {
  const _WifeMovementNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    currentIndex: 1,
    items: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
      NavigationDestination(
        icon: Icon(Icons.monitor_heart_outlined),
        label: '실시간',
      ),
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '챗봇'),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: '캘린더',
      ),
    ],
    onSelected: onSelected,
  );
}

class _PartnerMovementNavigation extends StatelessWidget {
  const _PartnerMovementNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    currentIndex: 1,
    items: const [
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: '캘린더',
      ),
      NavigationDestination(
        icon: Icon(Icons.monitor_heart_outlined),
        label: '실시간',
      ),
    ],
    onSelected: onSelected,
  );
}
