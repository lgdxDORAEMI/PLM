import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../invitation/controllers/partner_invite_controller.dart';
import '../../invitation/models/invitation.dart';
import '../../invitation/services/invitation_service.dart';
import '../../invitation/services/mock_invitation_service.dart';

class PartnerInviteScreen extends StatefulWidget {
  const PartnerInviteScreen({
    super.key,
    required this.entryContext,
    this.service,
  });

  final InviteEntryContext entryContext;
  final InvitationService? service;

  @override
  State<PartnerInviteScreen> createState() => _PartnerInviteScreenState();
}

class _PartnerInviteScreenState extends State<PartnerInviteScreen> {
  late final PartnerInviteController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PartnerInviteController(
      service: widget.service ?? const MockInvitationService(),
    )..addListener(_refresh);
    unawaited(_controller.load());
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
    appBar: TopAppBar(title: '남편 초대하기', onBack: _handleBack),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(child: _buildBody()),
    ),
  );

  Widget _buildBody() => switch (_controller.state) {
    InvitationActionState.loading => const AppLoadingState(
      message: '초대 링크를 준비하고 있어요',
    ),
    InvitationActionState.error => AppErrorState(
      title: '초대 링크를 만들지 못했어요',
      message: '잠시 후 다시 시도해 주세요.',
      onRetry: _controller.load,
    ),
    _ => ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        const _InviteHero(),
        const SizedBox(height: AppSpacing.xl),
        Text('연결하면 이런 게 가능해요', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const _BenefitCard(
          icon: Icons.fact_check_outlined,
          title: '오늘 컨디션 요약 받기',
          description: '공유에 동의한 항목만 남편에게 보여요',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _BenefitCard(
          icon: Icons.home_outlined,
          title: '집안일 · 식사 요청 받기',
          description: '가사 가이드에서 보낸 요청이 바로 도착해요',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _BenefitCard(
          icon: Icons.calendar_month_outlined,
          title: '하루 리포트 함께 보기',
          description: '가족 분담이 캘린더에 자동 정리돼요',
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('초대 링크', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _controller.link!,
                  key: const ValueKey('partner-invite-link'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(onPressed: _copyLink, child: const Text('복사')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppButton(
                key: const ValueKey('partner-invite-send'),
                label: _controller.state == InvitationActionState.submitting
                    ? '보내는 중…'
                    : '링크 보내기',
                onPressed: _controller.state == InvitationActionState.submitting
                    ? null
                    : _send,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: '나중에',
                variant: AppButtonVariant.secondary,
                onPressed: _finish,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '남편이 링크를 열면 ThinQ 설치와 로그인 후 연결할 수 있어요.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  };

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _controller.link!));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 링크를 복사했어요.')));
  }

  Future<void> _send() async {
    if (!await _controller.send() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('초대 링크를 준비했어요'),
        content: const Text('현재는 Mock 공유 상태이며 실제 OS 공유 시트는 연결하지 않았어요.'),
        actions: [
          AppButton(label: '확인', onPressed: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
    if (mounted) _finish();
  }

  void _finish() {
    if (widget.entryContext == InviteEntryContext.onboarding) {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _finish();
    }
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '남편도 ThinQ에 연결해보세요',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('설치와 가입은 링크 하나로 끝나요'),
      ],
    ),
  );
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary600, size: 28),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
