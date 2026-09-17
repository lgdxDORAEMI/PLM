import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/app_router.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../controllers/entry_controller.dart';
import '../services/entry_service.dart';
import '../services/mock_entry_service.dart';
import '../widgets/pregnancy_entry_view.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, this.service, this.invitationToken});

  final EntryService? service;
  final String? invitationToken;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final EntryController _controller;
  bool _redirectScheduled = false;

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

  /// Bootstrap 결과가 기존 사용자일 때만 역할별 시작 화면으로 이동한다.
  void _onChanged() {
    if (!mounted) return;

    final launchState = _controller.launchState;
    final shouldRedirect = _controller.state == EntryViewState.ready &&
        launchState != null &&
        launchState != AppLaunchState.wifeNeedsProfile;
    if (shouldRedirect && !_redirectScheduled) {
      _redirectScheduled = true;
      final route = AppRouter.resolveLaunchRoute(
        launchState,
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
      child: ResponsivePageContent(
        maxWidth: 1200,
        child: switch (_controller.state) {
          EntryViewState.loading => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: AppLoadingState(message: '사용자 상태를 확인하고 있어요.'),
              ),
            ),
          EntryViewState.error => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: AppErrorState(
                  title: 'Pregnancy Life Mode를 열지 못했어요',
                  message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                  onRetry: _controller.load,
                ),
              ),
            ),
          EntryViewState.ready => _buildReadyState(),
        },
      ),
    ),
  );

  Widget _buildReadyState() {
    if (_controller.launchState == AppLaunchState.wifeNeedsProfile) {
      return PregnancyEntryView(
        onStart: () => Navigator.pushReplacementNamed(
          context,
          RouteNames.profileSetup,
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: AppLoadingState(message: '시작 화면으로 이동하고 있어요.'),
      ),
    );
  }
}
