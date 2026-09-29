import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../services/api_entry_service.dart';
import '../services/entry_service.dart';

/// Sends an open husband screen back to entry when the wife resets sharing.
class HusbandLinkGuard extends StatefulWidget {
  const HusbandLinkGuard({
    super.key,
    required this.child,
    this.service,
    this.pollInterval = const Duration(seconds: 3),
  });

  final Widget child;
  final EntryService? service;
  final Duration pollInterval;

  @override
  State<HusbandLinkGuard> createState() => _HusbandLinkGuardState();
}

class _HusbandLinkGuardState extends State<HusbandLinkGuard>
    with WidgetsBindingObserver {
  late final EntryService _service = widget.service ?? ApiEntryService();
  Timer? _timer;
  bool _requestInFlight = false;
  bool _redirecting = false;

  bool get _enabled => widget.service != null || AppConfig.hasSupabaseConfig;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted || !_enabled || _redirecting) return;
    _timer?.cancel();
    unawaited(_checkLink());
    _timer = Timer.periodic(
      widget.pollInterval,
      (_) => unawaited(_checkLink()),
    );
  }

  Future<void> _checkLink() async {
    if (!mounted || _requestInFlight || _redirecting) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _requestInFlight = true;
    try {
      final state = await _service.resolveLaunchState();
      if (!mounted || state != AppLaunchState.partnerNeedsLink) return;
      _redirecting = true;
      _timer?.cancel();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.entry, (_) => false);
    } on Object {
      // A temporary network failure must not eject the husband from his screen.
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
