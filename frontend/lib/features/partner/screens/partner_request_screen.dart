import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../household/services/api_household_request_service.dart';
import '../../household/services/household_request_service.dart';
import '../../household/services/mock_household_request_service.dart';
import '../controllers/partner_request_controller.dart';
import '../models/partner_request.dart';

class PartnerRequestScreen extends StatefulWidget {
  const PartnerRequestScreen({
    super.key,
    required this.requestId,
    this.service,
  });

  final String requestId;
  final HouseholdRequestService? service;

  @override
  State<PartnerRequestScreen> createState() => _PartnerRequestScreenState();
}

class _PartnerRequestScreenState extends State<PartnerRequestScreen> {
  late final PartnerRequestController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PartnerRequestController(
      requestId: widget.requestId,
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiHouseholdRequestService()
              : MockHouseholdRequestService()),
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
  Widget build(BuildContext context) {
    final request = _controller.request;
    return Scaffold(
      appBar: TopAppBar(
        title: '가사 요청',
        onBack: _handleBack,
        husbandMenuAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: request == null
              ? _stateView()
              : ListView(
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
                          label: switch (request.status) {
                            PartnerRequestStatus.requested => '미확인',
                            PartnerRequestStatus.confirmed => '확인',
                            PartnerRequestStatus.completed => '완료',
                          },
                          tone: request.status == PartnerRequestStatus.completed
                              ? AppBadgeTone.success
                              : AppBadgeTone.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '부탁한 집안일',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: [
                        for (final task in request.tasks) ...[
                          _PartnerTaskCard(
                            task: task,
                            onConfirm: () =>
                                unawaited(_controller.confirmTask(task.id)),
                            onComplete: () => _confirmCompletion(task),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                    if (request.status == PartnerRequestStatus.completed) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: '완료 결과 보기',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          RouteNames.husbandRequestResult(request.id),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _stateView() => switch (_controller.state) {
    PartnerRequestViewState.loading => const AppLoadingState(
      message: '가사 요청을 불러오고 있어요',
    ),
    PartnerRequestViewState.empty => const AppEmptyState(
      title: '가사 요청을 찾을 수 없어요',
    ),
    PartnerRequestViewState.authError => AppErrorState(
      title: '가사 요청을 볼 수 없어요',
      message: '로그인 상태와 배우자 연결 권한을 확인해 주세요.',
      onRetry: _controller.load,
    ),
    PartnerRequestViewState.domainError => AppErrorState(
      title: '요청 상태를 변경할 수 없어요',
      message: '현재 요청 진행 상태를 다시 확인해 주세요.',
      onRetry: _controller.load,
    ),
    PartnerRequestViewState.serverError => AppErrorState(
      title: '서버에 연결할 수 없어요',
      onRetry: _controller.load,
    ),
    _ => AppErrorState(title: '가사 요청을 불러오지 못했어요', onRetry: _controller.load),
  };

  Future<void> _confirmCompletion(PartnerRequestTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 일을 다 하셨나요?'),
        content: Text('${task.title}\n\n이 집안일을 완료로 표시할까요?'),
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
    await _controller.completeTask(task.id);
    final request = _controller.request;
    if (!mounted || request == null) return;
    if (request.status == PartnerRequestStatus.completed) {
      Navigator.pushReplacementNamed(
        context,
        RouteNames.husbandRequestResult(request.id),
      );
    }
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
  Widget build(BuildContext context) {
    final (backgroundColor, borderColor) = switch (task.status) {
      PartnerRequestStatus.requested => (
        AppColors.surface,
        AppColors.borderSubtle,
      ),
      PartnerRequestStatus.confirmed => (
        AppColors.infoBackground,
        AppColors.info,
      ),
      PartnerRequestStatus.completed => (
        AppColors.successBackground,
        AppColors.success,
      ),
    };
    return AppCard(
      key: ValueKey('partner-request-task-${task.id}'),
      backgroundColor: backgroundColor,
      borderColor: borderColor,
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
          if (task.status != PartnerRequestStatus.completed) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: ValueKey(
                task.status == PartnerRequestStatus.requested
                    ? 'husband-request-confirm-${task.id}'
                    : 'husband-request-complete-${task.id}',
              ),
              label: task.status == PartnerRequestStatus.requested
                  ? '확인하기'
                  : '완료했어요',
              variant: task.status == PartnerRequestStatus.requested
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed: task.status == PartnerRequestStatus.requested
                  ? onConfirm
                  : onComplete,
            ),
          ],
        ],
      ),
    );
  }
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
