import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../calendar/data/calendar_selection_store.dart';
import '../../report/models/daily_record.dart';
import '../controllers/partner_notification_controller.dart';
import '../models/partner_notification.dart';

class PartnerNotificationsScreen extends StatefulWidget {
  const PartnerNotificationsScreen({super.key});

  @override
  State<PartnerNotificationsScreen> createState() =>
      _PartnerNotificationsScreenState();
}

class _PartnerNotificationsScreenState
    extends State<PartnerNotificationsScreen> {
  late final PartnerNotificationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PartnerNotificationController()..addListener(_refresh);
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
    appBar: TopAppBar(
      title: '알림',
      onBack: _handleBack,
      actions: [
        TextButton(
          onPressed: _controller.unreadCount == 0
              ? null
              : _controller.markAllRead,
          child: const Text('모두 읽음'),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            InfoBanner(
              title: _controller.unreadCount == 0
                  ? '새 알림이 없어요'
                  : '읽지 않은 알림 ${_controller.unreadCount}개',
              message: '오전 리포트·가사 요청·루틴 변경을 시간순으로 보여드려요.',
              tone: InfoBannerTone.info,
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final item in _controller.items) ...[
              _NotificationCard(item: item, onTap: () => _open(item)),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    ),
  );

  void _open(PartnerNotificationItem item) {
    _controller.markRead(item.id);
    final route = switch (item.type) {
      PartnerNotificationType.morningReport => RouteNames.partnerMorningReport(
        item.reportDate!,
      ),
      PartnerNotificationType.householdRequest => RouteNames.partnerRequest(
        item.requestId!,
      ),
      PartnerNotificationType.routineChanged => _routineChangedRoute(
        item.reportDate!,
      ),
    };
    Navigator.pushNamed(context, route);
  }

  String _routineChangedRoute(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed != null && recordDateKey(parsed) == date) {
      CalendarSelectionStore.instance.remember(parsed);
    }
    return RouteNames.husbandCalendar;
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final PartnerNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(item.type);
    return Semantics(
      button: true,
      label: '${item.read ? '읽음' : '읽지 않음'} ${visual.label}, ${item.title}',
      child: AppInkWell(
        borderRadius: BorderRadius.circular(16),
        key: ValueKey('notification-${item.id}'),
        onTap: onTap,
        child: AppCard(
          backgroundColor: visual.background,
          borderColor: visual.foreground.withValues(alpha: .28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surface,
                foregroundColor: visual.foreground,
                child: Icon(visual.icon),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(label: visual.label, tone: visual.badgeTone),
                        if (!item.read)
                          const AppBadge(
                            label: '새 알림',
                            tone: AppBadgeTone.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.message),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: visual.foreground),
            ],
          ),
        ),
      ),
    );
  }

  /// 알림 종류를 색상뿐 아니라 명시적인 라벨과 아이콘으로 함께 구분한다.
  _NotificationVisual _visualFor(PartnerNotificationType type) =>
      switch (type) {
        PartnerNotificationType.morningReport => const _NotificationVisual(
          label: '컨디션 리포트',
          icon: Icons.monitor_heart_outlined,
          foreground: AppColors.info,
          background: AppColors.infoBackground,
          badgeTone: AppBadgeTone.info,
        ),
        PartnerNotificationType.householdRequest => const _NotificationVisual(
          label: '가사 요청',
          icon: Icons.volunteer_activism_outlined,
          foreground: AppColors.categoryHousehold,
          background: AppColors.categoryHouseholdBackground,
          badgeTone: AppBadgeTone.household,
        ),
        PartnerNotificationType.routineChanged => const _NotificationVisual(
          label: '루틴 변경',
          icon: Icons.update_outlined,
          foreground: AppColors.primary700,
          background: AppColors.primary50,
          badgeTone: AppBadgeTone.primary,
        ),
      };
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.badgeTone,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final AppBadgeTone badgeTone;
}
