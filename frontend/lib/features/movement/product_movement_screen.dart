import 'package:flutter/material.dart';

import '../../design_system/components/bottom_navigation.dart';
import '../../design_system/components/responsive_page_content.dart';
import '../../design_system/components/top_app_bar.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radius.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../routing/route_context.dart';
import '../../routing/route_names.dart';
import 'models/movement_alert.dart';
import 'widgets/movement_alert_card.dart';

class ProductMovementScreen extends StatefulWidget {
  const ProductMovementScreen({super.key, required this.role});
  final AppUserRole role;
  @override
  State<ProductMovementScreen> createState() => _ProductMovementScreenState();
}

class _ProductMovementScreenState extends State<ProductMovementScreen> {
  bool _monitoring = true;

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
              monitoring: _monitoring,
              onChanged: (value) => setState(() => _monitoring = value),
              onMoveToHome: _moveToHousehold,
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
            for (final alert in MovementMockData.alerts) ...[
              MovementAlertCard(alert: alert, onTap: () => _showAlert(alert)),
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
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(alert.description),
            const SizedBox(height: AppSpacing.sm),
            Text(
              alert.suggestion,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('이 정보는 의료적 판단이나 통증 진단을 제공하지 않아요.'),
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
  final VoidCallback onMoveToHome;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      color: AppColors.successBackground,
      borderRadius: BorderRadius.circular(AppRadius.hero),
      border: Border.all(color: AppColors.success.withValues(alpha: .2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              child: Icon(Icons.camera_indoor_outlined),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('홈 카메라 움직임 감지'), Text('가전 내장 카메라 · mock 인식 중')],
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
        const Row(
          children: [
            Expanded(child: Text('오늘 서 있거나 움직인 시간')),
            Text('2시간 40분 / 권장 2시간'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const LinearProgressIndicator(
          value: .8,
          color: AppColors.success,
          backgroundColor: AppColors.warningBackground,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(child: Text('권장보다 40분 더 움직이셨어요')),
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
