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
import '../../../routing/route_refresh_observer.dart';
import '../../household/services/api_household_request_service.dart';
import '../../household/services/household_request_service.dart';
import '../../household/services/mock_household_request_service.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../controllers/partner_request_controller.dart';
import '../controllers/partner_request_list_controller.dart';
import '../models/partner_request.dart';

class PartnerRequestListScreen extends StatefulWidget {
  const PartnerRequestListScreen({super.key, this.targetDate, this.service});

  final String? targetDate;
  final HouseholdRequestService? service;

  @override
  State<PartnerRequestListScreen> createState() =>
      _PartnerRequestListScreenState();
}

class _PartnerRequestListScreenState extends State<PartnerRequestListScreen>
    with RouteAware, WidgetsBindingObserver {
  late final PartnerRequestListController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PartnerRequestListController(
      targetDate: widget.targetDate,
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiHouseholdRequestService()
              : MockHouseholdRequestService()),
    )..addListener(_refresh);
    unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      routeRefreshObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => unawaited(_controller.load());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_controller.load());
    }
  }

  @override
  void dispose() {
    routeRefreshObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(
      title: '가사 요청 내역',
      onBack: _handleBack,
      husbandMenuAction: true,
    ),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: IntegrationPreview(
          hasService: widget.service != null,
          child: _body(),
        ),
      ),
    ),
  );

  Widget _body() => switch (_controller.state) {
    PartnerRequestViewState.loading => const AppLoadingState(
      message: '가사 요청 내역을 불러오고 있어요',
    ),
    PartnerRequestViewState.empty => AppEmptyState(
      title: widget.targetDate == null
          ? '가사 요청 내역이 없어요'
          : '${widget.targetDate}에 받은 가사 요청이 없어요',
    ),
    PartnerRequestViewState.authError => AppErrorState(
      title: '가사 요청 내역을 볼 수 없어요',
      message: '로그인 상태와 배우자 연결 권한을 확인해 주세요.',
      onRetry: _controller.load,
    ),
    PartnerRequestViewState.serverError => AppErrorState(
      title: '서버에 연결할 수 없어요',
      onRetry: _controller.load,
    ),
    PartnerRequestViewState.data => ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        Text(
          '${widget.targetDate ?? '전체'} 요청 ${_controller.items.length}건',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in _controller.items) ...[
          _RequestTaskCard(
            item: item,
            updating: _controller.isUpdating(item.task.id),
            onConfirm: () => unawaited(
              _controller.confirmTask(item.request.id, item.task.id),
            ),
            onComplete: () => _confirmCompletion(item),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
    _ => AppErrorState(title: '가사 요청 내역을 불러오지 못했어요', onRetry: _controller.load),
  };

  Future<void> _confirmCompletion(PartnerRequestListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 집안일을 다 하셨나요?'),
        content: Text('${item.task.title}\n\n이 항목을 완료로 표시할까요?'),
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
    if (confirmed == true && mounted) {
      await _controller.completeTask(item.request.id, item.task.id);
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

class _RequestTaskCard extends StatelessWidget {
  const _RequestTaskCard({
    required this.item,
    required this.updating,
    required this.onConfirm,
    required this.onComplete,
  });

  final PartnerRequestListItem item;
  final bool updating;
  final VoidCallback onConfirm;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final (backgroundColor, borderColor) = switch (task.status) {
      PartnerRequestStatus.requested => (
        AppColors.surface,
        AppColors.primary600,
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
              _statusBadge(task.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${item.request.recordDate} · ${item.request.requester}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(task.description),
          ],
          if (task.status != PartnerRequestStatus.completed) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              key: ValueKey(
                task.status == PartnerRequestStatus.requested
                    ? 'husband-request-confirm-${task.id}'
                    : 'husband-request-complete-${task.id}',
              ),
              label: updating
                  ? '처리 중'
                  : task.status == PartnerRequestStatus.requested
                  ? '확인하기'
                  : '완료했어요',
              variant: task.status == PartnerRequestStatus.requested
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed: updating
                  ? null
                  : task.status == PartnerRequestStatus.requested
                  ? onConfirm
                  : onComplete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(PartnerRequestStatus status) => AppBadge(
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
