import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/app_router.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../controllers/entry_controller.dart';
import '../services/account_session_service.dart';
import '../services/api_entry_service.dart';
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
  static bool _defaultSessionEstablished = false;
  late final EntryController _controller;
  bool _redirectScheduled = false;
  late final bool _apiMode;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signingIn = false;
  String? _signInError;
  bool _automaticSignInFailed = false;
  bool _automaticSignInInProgress = false;

  bool get _automaticEntry => _apiMode && widget.invitationToken == null;

  @override
  void initState() {
    super.initState();
    _apiMode = AppConfig.hasSupabaseConfig && widget.service == null;
    _controller = EntryController(
      service:
          widget.service ??
          (_apiMode ? ApiEntryService() : const MockEntryService()),
    )..addListener(_onChanged);
    if (_automaticEntry &&
        (!_defaultSessionEstablished ||
            Supabase.instance.client.auth.currentSession == null)) {
      unawaited(_startDefaultSession());
    } else if (!_apiMode ||
        Supabase.instance.client.auth.currentSession != null) {
      unawaited(_controller.load());
    }
  }

  /// Fresh launches always authenticate the configured wife before bootstrap.
  Future<void> _startDefaultSession() async {
    if (_automaticSignInInProgress) return;
    _automaticSignInInProgress = true;
    setState(() => _automaticSignInFailed = false);
    try {
      final launchState = await AccountSessionService().startAsWife();
      _defaultSessionEstablished = true;
      if (mounted) _controller.complete(launchState);
    } catch (_) {
      if (mounted) setState(() => _automaticSignInFailed = true);
    } finally {
      _automaticSignInInProgress = false;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Bootstrap 결과가 기존 사용자일 때만 역할별 시작 화면으로 이동한다.
  void _onChanged() {
    if (!mounted) return;

    final launchState = _controller.launchState;
    final shouldRedirect =
        _controller.state == EntryViewState.ready &&
        launchState != null &&
        launchState != AppLaunchState.wifeNeedsProfile &&
        (launchState != AppLaunchState.partnerNeedsLink ||
            widget.invitationToken != null);
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
        child: _automaticEntry && _automaticSignInFailed
            ? Center(
                child: AppErrorState(
                  title: '계정에 연결하지 못했어요',
                  message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                  onRetry: _startDefaultSession,
                ),
              )
            : _automaticEntry && !_defaultSessionEstablished
            ? const Center(child: AppLoadingState(message: '계정에 연결하고 있어요.'))
            : _apiMode && Supabase.instance.client.auth.currentSession == null
            ? _buildSignIn()
            : switch (_controller.state) {
                EntryViewState.loading => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    child: AppLoadingState(message: '사용자 상태를 확인하고 있어요.'),
                  ),
                ),
                EntryViewState.error => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                    ),
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

  Widget _buildSignIn() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('로그인', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          AppInput(
            label: '이메일',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('비밀번호', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
          ),
          if (_signInError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _signInError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: '로그인',
            loading: _signingIn,
            onPressed: _signingIn ? null : _signIn,
          ),
        ],
      ),
    ),
  );

  /// Starts backend bootstrap only after Supabase supplies a valid session.
  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await _controller.load();
    } catch (_) {
      if (mounted) setState(() => _signInError = '로그인하지 못했어요. 계정 정보를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Widget _buildReadyState() {
    if (_controller.launchState == AppLaunchState.partnerNeedsLink) {
      return const Center(
        child: AppEmptyState(
          title: '초대 연결이 필요해요',
          message: '아내가 보낸 초대 링크를 열어 연결을 완료해 주세요.',
          icon: Icons.link_outlined,
        ),
      );
    }
    if (_controller.launchState == AppLaunchState.wifeNeedsProfile) {
      return PregnancyEntryView(
        onStart: () =>
            Navigator.pushReplacementNamed(context, RouteNames.profileSetup),
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
