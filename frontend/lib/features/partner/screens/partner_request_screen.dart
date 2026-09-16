import 'package:flutter/material.dart';

import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/partner_request_controller.dart';
import '../models/partner_request.dart';

class PartnerRequestScreen extends StatefulWidget {
  const PartnerRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<PartnerRequestScreen> createState() => _PartnerRequestScreenState();
}

class _PartnerRequestScreenState extends State<PartnerRequestScreen> {
  late final PartnerRequestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PartnerRequestController(requestId: widget.requestId)
      ..addListener(_refresh);
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
  Widget build(BuildContext context) {
    final request = _controller.request;
    return Scaffold(
      appBar: TopAppBar(title: '가사 요청', onBack: _handleBack),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: ListView(
            key: const ValueKey('partner-request-content'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${request.requester}이 도움을 요청했어요',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  AppBadge(
                    label:
                        '확인 ${request.confirmedCount} · 완료 ${request.completedCount}',
                    tone: request.completedCount == request.tasks.length
                        ? AppBadgeTone.success
                        : AppBadgeTone.info,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '요청 번호 · ${request.id}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              InfoBanner(
                title: '오늘 요청한 이유',
                message: request.reason,
                tone: InfoBannerTone.warning,
                icon: Icons.favorite_outline,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('부탁한 집안일', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              for (final task in request.tasks) ...[
                _PartnerTaskCard(
                  task: task,
                  onConfirm: () => _controller.confirmTask(task.id),
                  onComplete: () => _confirmCompletion(task),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '참고 정보',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(request.supportingInfo),
                  ],
                ),
              ),
              if (request.confirmedCount > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoBanner(
                  title: request.completedCount == request.tasks.length
                      ? '모든 요청이 가족 기록에 반영됐어요'
                      : '확인 상태가 희선님 화면에 반영됐어요',
                  message: '요청 내용은 완료 후에도 다시 볼 수 있어요.',
                  tone: request.completedCount == request.tasks.length
                      ? InfoBannerTone.success
                      : InfoBannerTone.info,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCompletion(PartnerRequestTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 일을 다 하셨나요?'),
        content: Text('${task.title}\n완료로 표시하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('아직이에요'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('완료했어요'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _controller.completeTask(task.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 48,
        ),
        title: const Text('완료 처리됐어요'),
        content: Text(
          '희선님 화면 · 내 캘린더 · 일일 리포트에 반영돼요.\n\n'
          '요청 ${_controller.request.tasks.length}건 · 확인 ${_controller.request.confirmedCount}건 · 완료 ${_controller.request.completedCount}건',
        ),
        actions: [
          AppButton(
            label: '캘린더로 돌아가기',
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacementNamed(
                context,
                RouteNames.partnerCalendar,
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }
}

class _PartnerTaskCard extends StatelessWidget {
  const _PartnerTaskCard({
    required this.task,
    required this.onConfirm,
    required this.onComplete,
  });

  final PartnerRequestTask task;
  final VoidCallback onConfirm;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _StatusBadge(status: task.status),
          ],
        ),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        switch (task.status) {
          PartnerRequestStatus.requested => AppButton(
            key: ValueKey('partner-request-confirm-${task.id}'),
            label: '확인',
            onPressed: onConfirm,
          ),
          PartnerRequestStatus.confirmed => AppButton(
            key: ValueKey('partner-request-complete-${task.id}'),
            label: '완료했어요',
            onPressed: onComplete,
          ),
          PartnerRequestStatus.completed => const AppButton(
            label: '완료됨',
            onPressed: null,
          ),
        },
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PartnerRequestStatus status;

  @override
  Widget build(BuildContext context) => AppBadge(
    label: switch (status) {
      PartnerRequestStatus.requested => '요청됨',
      PartnerRequestStatus.confirmed => '확인됨',
      PartnerRequestStatus.completed => '완료됨',
    },
    tone: switch (status) {
      PartnerRequestStatus.requested => AppBadgeTone.primary,
      PartnerRequestStatus.confirmed => AppBadgeTone.info,
      PartnerRequestStatus.completed => AppBadgeTone.success,
    },
  );
}
