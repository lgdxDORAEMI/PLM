import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../routing/app_session.dart';
import '../../../routing/route_names.dart';
import '../../invitation/data/partner_connection_store.dart';
import '../../invitation/controllers/invitation_entry_controller.dart';
import '../../invitation/models/invitation.dart';
import '../../invitation/services/invitation_service.dart';
import '../../invitation/services/mock_invitation_service.dart';

class InvitationEntryScreen extends StatefulWidget {
  const InvitationEntryScreen({super.key, required this.token, this.service});

  final String? token;
  final InvitationService? service;

  @override
  State<InvitationEntryScreen> createState() => _InvitationEntryScreenState();
}

class _InvitationEntryScreenState extends State<InvitationEntryScreen> {
  late final InvitationEntryController _controller;
  bool _linkScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = InvitationEntryController(
      service: widget.service ?? const MockInvitationService(),
      token: widget.token,
    )..addListener(_refresh);
    unawaited(_controller.validate());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (!_linkScheduled &&
        _controller.state == InvitationActionState.ready &&
        _controller.tokenStatus == InvitationTokenStatus.valid) {
      _linkScheduled = true;
      unawaited(_completeLink());
    }
    setState(() {});
  }

  Future<void> _completeLink() async {
    final token = widget.token;
    if (token == null) return;
    try {
      await _controller.service.accept(token);
      if (!mounted) return;
      PartnerConnectionStore.instance.markLinked();
      final auth = AuthSessionStore.instance;
      auth.update(
        accountId: auth.accountId ?? 'demo-husband',
        // 초대 연결은 현재 ThinQ 계정의 역할 권한을 새로 부여하지 않는다.
        // husband 권한은 인증/세션 조회 결과로 이미 확인되어 있어야 한다.
        roles: auth.roles,
        husbandLinked: true,
      );
      final switched = ActiveRoleStore.instance.switchTo(
        ActiveRole.husband,
        auth,
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        switched ? RouteNames.husbandCalendar : RouteNames.entry,
        (_) => false,
      );
    } on Object {
      if (!mounted) return;
      _linkScheduled = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopAppBar(title: '초대 수락', showBack: false),
    body: SafeArea(top: false, child: ResponsivePageContent(child: _body())),
  );

  Widget _body() {
    if (_controller.state == InvitationActionState.loading) {
      return const AppLoadingState(message: 'ThinQ 초대를 확인하고 있어요');
    }
    if (_controller.state == InvitationActionState.error) {
      return AppErrorState(
        title: '초대를 확인하지 못했어요',
        message: '네트워크 상태를 확인하고 다시 시도해 주세요.',
        onRetry: _controller.validate,
      );
    }
    if (_controller.tokenStatus != InvitationTokenStatus.valid) {
      return _InvalidInvitation(status: _controller.tokenStatus);
    }
    return const AppLoadingState(message: '계정을 연결하고 남편 캘린더로 이동하고 있어요');
  }
}

class _InvalidInvitation extends StatelessWidget {
  const _InvalidInvitation({required this.status});

  final InvitationTokenStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      InvitationTokenStatus.expired => '초대의 유효 시간이 지났어요.',
      InvitationTokenStatus.used => '이미 사용된 초대예요.',
      InvitationTokenStatus.duplicate => '이미 다른 계정과 연결되어 있어요.',
      _ => '초대 정보가 없어요.',
    };
    return Center(
      child: InfoBanner(
        title: '연결할 수 없어요',
        message: '$message\n아내에게 새 초대장을 요청해 주세요.',
        tone: InfoBannerTone.warning,
      ),
    );
  }
}
