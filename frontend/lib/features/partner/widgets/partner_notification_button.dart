import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../../routing/route_refresh_observer.dart';
import '../services/api_partner_notification_service.dart';
import '../services/mock_partner_notification_service.dart';
import '../services/partner_notification_service.dart';

/// 남편 화면 오른쪽 위 알림 버튼. 읽지 않은 알림이 있으면 빨간 점을 띄운다.
class PartnerNotificationButton extends StatefulWidget {
  const PartnerNotificationButton({super.key, this.service});

  final PartnerNotificationService? service;

  @override
  State<PartnerNotificationButton> createState() =>
      _PartnerNotificationButtonState();
}

class _PartnerNotificationButtonState extends State<PartnerNotificationButton>
    with RouteAware {
  static final _sharedPoller = _PartnerNotificationPoller(
    AppConfig.hasSupabaseConfig
        ? ApiPartnerNotificationService()
        : const MockPartnerNotificationService(),
  );

  late final _PartnerNotificationPoller _poller = widget.service == null
      ? _sharedPoller
      : _PartnerNotificationPoller(widget.service!);
  PageRoute<dynamic>? _route;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _poller.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic> || identical(route, _route)) return;
    if (_route != null) routeRefreshObserver.unsubscribe(this);
    _route = route;
    routeRefreshObserver.subscribe(this, route);
    if (route.isCurrent) _activate();
  }

  @override
  void didPush() => _activate();

  @override
  void didPopNext() => _activate();

  @override
  void didPushNext() => _deactivate();

  @override
  void didPop() => _deactivate();

  @override
  void dispose() {
    routeRefreshObserver.unsubscribe(this);
    _deactivate();
    _poller.removeListener(_refresh);
    if (widget.service != null) _poller.dispose();
    super.dispose();
  }

  void _activate() {
    if (_active) return;
    _active = true;
    _poller.activate();
  }

  void _deactivate() {
    if (!_active) return;
    _active = false;
    _poller.deactivate();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    await Navigator.pushNamed(context, RouteNames.partnerNotifications);
    await _poller.refresh();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '알림',
    onPressed: _open,
    icon: Semantics(
      value: _poller.hasUnread ? '읽지 않은 알림 있음' : null,
      child: Badge(
        key: const ValueKey('partner-notification-badge'),
        isLabelVisible: _poller.hasUnread,
        smallSize: 8,
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_outlined),
      ),
    ),
  );
}

/// 화면마다 타이머를 만들지 않고, 활성화된 남편 화면들이 하나의 조회를 공유한다.
class _PartnerNotificationPoller extends ChangeNotifier
    with WidgetsBindingObserver {
  _PartnerNotificationPoller(this._service);

  static const pollInterval = Duration(seconds: 5);
  static const maxRetryInterval = Duration(seconds: 30);

  final PartnerNotificationService _service;
  Timer? _timer;
  int _activeClients = 0;
  int _consecutiveFailures = 0;
  bool _requestInFlight = false;
  bool _hasUnread = false;
  bool _observingLifecycle = false;
  bool _disposed = false;

  bool get hasUnread => _hasUnread;

  void activate() {
    if (_disposed) return;
    _activeClients += 1;
    if (_activeClients != 1) return;
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    unawaited(refresh());
  }

  void deactivate() {
    if (_activeClients == 0) return;
    _activeClients -= 1;
    if (_activeClients != 0) return;
    _timer?.cancel();
    _timer = null;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_disposed || _activeClients == 0 || _requestInFlight) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;

    _timer?.cancel();
    _timer = null;
    _requestInFlight = true;
    try {
      final next = await _service.hasUnread();
      if (_disposed) return;
      _consecutiveFailures = 0;
      if (_hasUnread != next) {
        _hasUnread = next;
        notifyListeners();
      }
    } catch (_) {
      _consecutiveFailures += 1;
    } finally {
      _requestInFlight = false;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    if (_disposed || _activeClients == 0) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final multiplier = 1 << _consecutiveFailures.clamp(0, 3);
    final retry = pollInterval * multiplier;
    final delay = retry > maxRetryInterval ? maxRetryInterval : retry;
    _timer = Timer(delay, () => unawaited(refresh()));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
