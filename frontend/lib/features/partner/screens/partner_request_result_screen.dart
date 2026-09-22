import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../../routing/route_refresh_observer.dart';
import '../../household/services/api_household_request_service.dart';
import '../../household/services/household_request_service.dart';
import '../../household/services/mock_household_request_service.dart';
import '../controllers/partner_request_controller.dart';
import '../models/partner_request.dart';
import '../../../shared/widgets/integration_required_state.dart';

/// H-REQUEST-002. 완료된 요청도 상세 API를 다시 조회해 직접 URL 진입을 지원한다.
class PartnerRequestResultScreen extends StatefulWidget {
  const PartnerRequestResultScreen({
    super.key,
    required this.requestId,
    this.service,
  });

  final String requestId;
  final HouseholdRequestService? service;

  @override
  State<PartnerRequestResultScreen> createState() =>
      _PartnerRequestResultScreenState();
}

class _PartnerRequestResultScreenState extends State<PartnerRequestResultScreen>
    with RouteAware, WidgetsBindingObserver {
  late final PartnerRequestController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      title: '요청 완료',
      onBack: () => _goCalendar(context),
      husbandMenuAction: true,
    ),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: IntegrationPreview(
          hasService: widget.service != null,
          child: _buildBody(),
        ),
      ),
    ),
  );

  Widget _buildBody() {
    final request = _controller.request;
    if (request == null) {
      return switch (_controller.state) {
        PartnerRequestViewState.loading => const AppLoadingState(
          message: '완료 결과를 불러오고 있어요',
        ),
        PartnerRequestViewState.empty => const AppEmptyState(
          title: '완료된 요청을 찾을 수 없어요',
        ),
        PartnerRequestViewState.authError => AppErrorState(
          title: '완료 결과를 볼 수 없어요',
          message: '로그인 상태와 배우자 연결 권한을 확인해 주세요.',
          onRetry: _controller.load,
        ),
        _ => AppErrorState(
          title: '완료 결과를 불러오지 못했어요',
          onRetry: _controller.load,
        ),
      };
    }
    return _ResultContent(request: request);
  }

  static void _goCalendar(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.husbandCalendar,
        (_) => false,
      );
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.request});

  final PartnerRequestData request;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    children: [
      const Icon(Icons.check_circle, size: 72, color: AppColors.success),
      const SizedBox(height: AppSpacing.lg),
      Text(
        '가사 요청을 완료했어요',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text('완료 상태가 아내 화면과 가족 기록에 반영됐어요.', textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xl),
      const InfoBanner(
        title: '반영 위치',
        message: '아내 가사 가이드 · 내 캘린더 · Daily 리포트',
        tone: InfoBannerTone.success,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('가족 분담 요약', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            _count('요청받은 집안일', request.dailyRequestedCount),
            _count('내가 확인한 항목', request.dailyConfirmedCount),
            _count('내가 완료한 항목', request.dailyCompletedCount),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: '캘린더로 돌아가기',
        onPressed: () => _PartnerRequestResultScreenState._goCalendar(context),
      ),
    ],
  );

  Widget _count(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$count건', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
