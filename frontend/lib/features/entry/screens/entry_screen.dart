import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/app_router.dart';
import '../controllers/entry_controller.dart';
import '../services/entry_service.dart';
import '../services/mock_entry_service.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, this.service, this.invitationToken});

  final EntryService? service;
  final String? invitationToken;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final EntryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EntryController(
      service: widget.service ?? const MockEntryService(),
    )..addListener(_onChanged);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_controller.state == EntryViewState.ready) {
      final route = AppRouter.resolveLaunchRoute(
        _controller.launchState!,
        invitationToken: widget.invitationToken,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, route);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ResponsivePageContent.form(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: _controller.state == EntryViewState.error
                ? AppErrorState(
                    title: 'Pregnancy Life Mode를 열지 못했어요',
                    message: 'ThinQ 로그인과 연결 상태를 확인한 뒤 다시 시도해 주세요.',
                    onRetry: _controller.load,
                  )
                : const AppLoadingState(message: '사용자 상태를 확인하고 있어요'),
          ),
        ),
      ),
    ),
  );
}
