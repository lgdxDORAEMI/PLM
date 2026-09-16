import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
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

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TopAppBar(title: '초대 수락', showBack: false),
    body: SafeArea(top: false, child: ResponsivePageContent(child: _body())),
  );

  Widget _body() {
    if (_controller.state == InvitationActionState.loading) {
      return const AppLoadingState(message: '초대 링크를 확인하고 있어요');
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        const Icon(
          Icons.family_restroom,
          color: AppColors.primary600,
          size: 64,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '희선님이 함께 보자고 초대했어요',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'ThinQ 로그인 후 오늘 컨디션 요약과 가족 분담 기록을 함께 볼 수 있어요.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _JoinStep(number: 1, title: 'ThinQ 앱 설치 확인'),
        const SizedBox(height: AppSpacing.sm),
        const _JoinStep(number: 2, title: '가입 또는 로그인'),
        const SizedBox(height: AppSpacing.sm),
        const _JoinStep(number: 3, title: '희선님 계정과 연결'),
        const SizedBox(height: AppSpacing.xl),
        const InfoBanner(
          title: '공유 범위 안내',
          message: '아내가 공유에 동의한 컨디션 요약과 요청·기록만 표시돼요.',
          tone: InfoBannerTone.info,
        ),
        const SizedBox(height: AppSpacing.xl),
        const InfoBanner(
          title: '초대 수락은 개발 중입니다',
          message: 'ThinQ 가입·로그인 및 실제 계정 연결은 아직 제공되지 않아요.',
          tone: InfoBannerTone.warning,
        ),
      ],
    );
  }
}

class _JoinStep extends StatelessWidget {
  const _JoinStep({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary100,
          foregroundColor: AppColors.primary700,
          child: Text('$number'),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );
}

class _InvalidInvitation extends StatelessWidget {
  const _InvalidInvitation({required this.status});

  final InvitationTokenStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      InvitationTokenStatus.expired => '초대 링크의 유효 시간이 지났어요.',
      InvitationTokenStatus.used => '이미 사용된 초대 링크예요.',
      InvitationTokenStatus.duplicate => '이미 다른 계정과 연결되어 있어요.',
      _ => '초대 정보가 없는 링크예요.',
    };
    return Center(
      child: InfoBanner(
        title: '연결할 수 없어요',
        message: '$message\n아내에게 새 초대 링크를 요청해 주세요.',
        tone: InfoBannerTone.warning,
      ),
    );
  }
}
