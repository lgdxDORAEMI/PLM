import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_badge.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
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
  const PartnerRequestListScreen({super.key, this.service});

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
    PartnerRequestViewState.empty => const AppEmptyState(
      title: '가사 요청 내역이 없어요',
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
          '전체 요청 ${_controller.requests.length}건',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final request in _controller.requests) ...[
          _RequestSummaryCard(request: request),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
    _ => AppErrorState(title: '가사 요청 내역을 불러오지 못했어요', onRetry: _controller.load),
  };

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.partnerCalendar);
    }
  }
}

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});

  final PartnerRequestData request;

  @override
  Widget build(BuildContext context) => AppCard(
    key: ValueKey('partner-request-summary-${request.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                request.recordDate,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _statusBadge(request.status),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final task in request.tasks) ...[
          Row(
            children: [
              Expanded(child: Text(task.title)),
              const SizedBox(width: AppSpacing.sm),
              _statusBadge(task.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          key: ValueKey('partner-request-open-${request.id}'),
          label: '요청 보기',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pushNamed(
            context,
            RouteNames.partnerRequest(request.id),
          ),
        ),
      ],
    ),
  );

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
