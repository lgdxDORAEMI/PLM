import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../routing/route_names.dart';
import '../services/api_partner_notification_service.dart';
import '../services/mock_partner_notification_service.dart';
import '../services/partner_notification_service.dart';

/// 남편 화면 오른쪽 위 알림 버튼. 읽지 않은 알림이 있으면 빨간 점을 띄운다(09-29).
class PartnerNotificationButton extends StatefulWidget {
  const PartnerNotificationButton({super.key, this.service});

  final PartnerNotificationService? service;

  @override
  State<PartnerNotificationButton> createState() =>
      _PartnerNotificationButtonState();
}

class _PartnerNotificationButtonState extends State<PartnerNotificationButton>
    with WidgetsBindingObserver {
  // ponytail: 30초 주기 조회. 즉시 표시가 필요하면 Supabase Realtime 구독으로 바꾼다.
  static const _pollInterval = Duration(seconds: 30);

  late final PartnerNotificationService _service =
      widget.service ??
      (AppConfig.hasSupabaseConfig
          ? ApiPartnerNotificationService()
          : const MockPartnerNotificationService());
  Timer? _timer;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_check()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final items = await _service.fetchAll();
      if (mounted) setState(() => _hasUnread = items.any((item) => !item.read));
    } catch (_) {
      // 점은 보조 표시라 조회 실패(공개 전 403 포함)는 조용히 넘긴다.
    }
  }

  Future<void> _open() async {
    await Navigator.pushNamed(context, RouteNames.partnerNotifications);
    await _check();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '알림',
    onPressed: _open,
    icon: Semantics(
      value: _hasUnread ? '읽지 않은 알림 있음' : null,
      child: Badge(
        key: const ValueKey('partner-notification-badge'),
        isLabelVisible: _hasUnread,
        smallSize: 8,
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_outlined),
      ),
    ),
  );
}
