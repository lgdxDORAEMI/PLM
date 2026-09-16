import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
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
              message: '리포트와 가사 요청을 시간순으로 보여드려요.',
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
    };
    Navigator.pushNamed(context, route);
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${item.read ? '읽음' : '읽지 않음'} ${item.title}',
    child: InkWell(
      key: ValueKey('notification-${item.id}'),
      onTap: onTap,
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: item.read
                  ? AppColors.surfaceSubtle
                  : AppColors.primary100,
              foregroundColor: item.read
                  ? AppColors.textSecondary
                  : AppColors.primary700,
              child: Icon(
                item.type == PartnerNotificationType.morningReport
                    ? Icons.fact_check_outlined
                    : Icons.home_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (!item.read)
                        const AppBadge(
                          label: '새 알림',
                          tone: AppBadgeTone.primary,
                        ),
                    ],
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
          ],
        ),
      ),
    ),
  );
}
