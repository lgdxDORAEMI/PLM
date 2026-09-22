import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/hero_card.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../../condition/services/api_planned_activity_service.dart';
import '../../condition/services/mock_planned_activity_service.dart';
import '../../condition/services/planned_activity_service.dart';
import '../../invitation/data/invite_presentation_store.dart';
import '../../invitation/models/partner_link.dart';
import '../../invitation/services/api_partner_link_service.dart';
import '../../invitation/services/partner_link_service.dart';
import '../../invitation/controllers/partner_invite_controller.dart';
import '../../invitation/models/invitation.dart';
import '../../invitation/services/invitation_service.dart';
import '../../invitation/services/mock_invitation_service.dart';
import '../../invitation/services/api_invitation_service.dart';

class PartnerInviteScreen extends StatefulWidget {
  const PartnerInviteScreen({
    super.key,
    required this.entryContext,
    this.service,
    this.activityService,
    this.partnerLinkService,
  });

  final InviteEntryContext entryContext;
  final InvitationService? service;
  final PlannedActivityService? activityService;
  final PartnerLinkService? partnerLinkService;

  @override
  State<PartnerInviteScreen> createState() => _PartnerInviteScreenState();
}

class _PartnerInviteScreenState extends State<PartnerInviteScreen> {
  late final PartnerInviteController _controller;
  PartnerLink? _partnerLink;
  bool _checkingLink = false;
  bool _linkError = false;
  bool _showConnection = false;
  bool _generating = false;

  bool get _linked => _partnerLink?.linked ?? false;

  @override
  void initState() {
    super.initState();
    _controller = PartnerInviteController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiInvitationService()
              : const MockInvitationService()),
    )..addListener(_refresh);
    if (widget.partnerLinkService != null || AppConfig.hasSupabaseConfig) {
      unawaited(_loadPartnerLink());
    } else if (widget.service != null) {
      unawaited(_controller.load());
    }
  }

  Future<void> _loadPartnerLink() async {
    setState(() {
      _checkingLink = true;
      _linkError = false;
    });
    try {
      final link = await (widget.partnerLinkService ?? ApiPartnerLinkService())
          .fetch();
      if (mounted) setState(() => _partnerLink = link);
    } catch (_) {
      if (mounted) setState(() => _linkError = true);
    } finally {
      if (mounted) setState(() => _checkingLink = false);
    }
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
      title: '남편 초대하기',
      onBack: _handleBack,
      wifeProfileAction: true,
    ),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(child: _buildBody()),
    ),
  );

  Widget _buildBody() => switch (_controller.state) {
    _ when _checkingLink => const AppLoadingState(
      message: '배우자 연결 상태를 확인하고 있어요',
    ),
    _ when _linkError => AppErrorState(
      title: '배우자 연결 상태를 불러오지 못했어요',
      onRetry: _loadPartnerLink,
    ),
    _ when _showConnection && _linked => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_partnerLink?.partnerDisplayName ?? '배우자'}님과 연결됐어요'),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.entryContext == InviteEntryContext.onboarding
                ? '홈으로 이동'
                : '메뉴로 돌아가기',
            onPressed: _generating ? null : () => unawaited(_finish()),
          ),
        ],
      ),
    ),
    InvitationActionState.error
        when widget.service != null || AppConfig.hasSupabaseConfig =>
      AppErrorState(
        title: '초대를 준비하지 못했어요',
        message: '잠시 후 다시 시도해 주세요.',
        onRetry: _controller.load,
      ),
    _ => ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        const _InviteHero(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '연결하면 이런 게 가능해요',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        const _BenefitCard(
          number: 1,
          title: '오늘 컨디션 요약 받기',
          description: '공유에 동의한 항목만 남편에게 보여요',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _BenefitCard(
          number: 2,
          title: '집안일 · 식사 요청 받기',
          description: '가사 가이드에서 보낸 요청이 바로 도착해요',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _BenefitCard(
          number: 3,
          title: '하루 리포트 함께 보기',
          description: '가족 분담이 캘린더에 자동 정리돼요',
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (!_linked) ...[
          const AppCard(child: Text('초대장은 남편의 ThinQ 앱 알림으로 전송돼요.')),
          const SizedBox(height: AppSpacing.xl),
        ],
        // 시안: 두 버튼 같은 폭, 라벨 Bold(700).
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
              labelLarge: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: AppButton(
                  key: const ValueKey('partner-invite-send'),
                  label: _controller.state == InvitationActionState.submitting
                      ? '보내는 중…'
                      : _linked
                      ? '초대하기'
                      : '초대장 보내기',
                  onPressed:
                      _controller.state == InvitationActionState.submitting ||
                          _generating
                      ? null
                      : _send,
                ),
              ),
              Expanded(
                child: AppButton(
                  label: '나중에',
                  variant: AppButtonVariant.secondary,
                  onPressed: _generating ? null : () => unawaited(_finish()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _linked
              ? '초대하기를 누르면 현재 연결된 가족을 확인할 수 있어요.'
              : '남편이 ThinQ 알림을 선택하고 연결을 완료하면 함께 볼 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  };

  Future<void> _send() async {
    if (_linked) {
      InvitePresentationStore.instance.acknowledgeLinkedPartner();
      if (widget.entryContext == InviteEntryContext.dailyFlow) {
        await _finish(showLinkedConfirmation: true);
        return;
      }
      setState(() => _showConnection = true);
      return;
    }
    if (widget.service == null && !AppConfig.hasSupabaseConfig) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('남편 초대장 전송은 연동이 필요합니다.')));
      return;
    }
    if (_controller.link == null) {
      await _controller.load();
      if (!mounted || _controller.state != InvitationActionState.ready) return;
    }
    if (!await _controller.send() || !mounted) return;
    if (AppConfig.hasSupabaseConfig && _controller.link != null) {
      await Clipboard.setData(ClipboardData(text: _controller.link!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 링크를 복사했어요. 남편에게 전달해 주세요.')),
      );
      await _finish();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('초대장을 보냈어요'),
        content: const Text('남편의 ThinQ 앱 알림으로 초대장을 전송했어요.'),
        actions: [
          AppButton(label: '확인', onPressed: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
    if (mounted) await _finish();
  }

  /// 초대 선택 직후 루틴 생성을 시작하고 실패하면 초대 화면에서 재시도한다.
  Future<void> _finish({bool showLinkedConfirmation = false}) async {
    if (widget.entryContext == InviteEntryContext.dailyFlow) {
      if (_generating) return;
      setState(() => _generating = true);
      final navigator = Navigator.of(context, rootNavigator: true);
      final loadingRoute = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope<void>(
          canPop: false,
          child: AlertDialog(
            title: const Text('AI 루틴 생성중...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLinkedConfirmation) ...[
                  Text('${_partnerLink?.partnerDisplayName ?? '배우자'}님과 연결됐어요'),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
      navigator.push(loadingRoute);
      var generated = false;
      try {
        final service =
            widget.activityService ??
            (AppConfig.hasSupabaseConfig
                ? ApiPlannedActivityService()
                : const MockPlannedActivityService());
        await service.generateRoutine();
        generated = true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘의 루틴을 만들지 못했어요. 다시 시도해 주세요.')),
          );
        }
      } finally {
        if (navigator.mounted && loadingRoute.isActive) {
          navigator.removeRoute(loadingRoute);
        }
        if (mounted) setState(() => _generating = false);
      }
      if (generated && mounted) {
        Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
      }
      return;
    }
    if (widget.entryContext == InviteEntryContext.onboarding) {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeMenu);
    }
  }

  void _handleBack() {
    if (widget.entryContext == InviteEntryContext.dailyFlow) {
      Navigator.pushReplacementNamed(context, RouteNames.activity);
      return;
    }
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
  Widget build(BuildContext context) => const HeroCard(
    title: '남편도 ThinQ에 연결해보세요',
    description: 'ThinQ 알림으로 안전하게 계정을 연결할 수 있어요.',
  );
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
    child: Row(
      spacing: 14,
      children: [
        // 시안: primary 원 안에 순번. 숫자색 #DDDBD3은 borderSubtle과 사실상 같아 토큰을 쓴다.
        ExcludeSemantics(
          child: Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary600,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.borderSubtle,
                fontSize: 26,
                height: 1,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.69,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
