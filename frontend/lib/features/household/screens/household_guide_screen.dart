import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_dialog.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../report/data/appliance_execution_store.dart';
import '../controllers/household_guide_controller.dart';
import '../models/household_task.dart';
import '../services/household_request_service.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../widgets/household_task_card.dart';

class HouseholdGuideScreen extends StatefulWidget {
  const HouseholdGuideScreen({super.key, this.requestService});

  final HouseholdRequestService? requestService;
  @override
  State<HouseholdGuideScreen> createState() => _HouseholdGuideScreenState();
}

class _HouseholdGuideScreenState extends State<HouseholdGuideScreen> {
  late final HouseholdGuideController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HouseholdGuideController(
      requestService: widget.requestService,
    )..addListener(_refresh);
    unawaited(_controller.loadGuide());
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
    return WifeNavigationScaffold(
      currentIndex: 0,
      allowReselect: true,
      appBar: TopAppBar(
        title: '가사 가이드',
        onBack: _handleBack,
        wifeProfileAction: true,
      ),
      body: IntegrationPreview(
        hasService: widget.requestService != null,
        child: _controller.loading
            ? const AppLoadingState(message: '가사 가이드를 불러오고 있어요.')
            : _controller.empty
            ? const AppEmptyState(
                title: '오늘의 가사 가이드가 없어요',
                message: '오늘 루틴이 만들어지면 이곳에 표시돼요.',
              )
            : _controller.loadFailed
            ? AppErrorState(
                title: '가사 가이드를 불러오지 못했어요',
                message: '연결 상태를 확인하고 다시 시도해 주세요.',
                onRetry: _controller.loadGuide,
              )
            : SafeArea(
                top: false,
                child: ContentFrame(
                  maxWidth: 1200,
                  child: ListView(
                    key: const ValueKey('household-guide-scroll'),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    children: [
                      // 시안: 상단 요약 카드(식사 가이드 인사 카드와 같은 구성, 가사 색).
                      const _GuideSummaryCard(),
                      const SizedBox(height: AppSpacing.xxl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final sections = [
                            _directSection(),
                            _partnerSection(),
                            _applianceSection(),
                          ];
                          if (constraints.maxWidth < AppBreakpoints.desktop) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                sections[0],
                                const SizedBox(height: AppSpacing.lg),
                                sections[1],
                                const SizedBox(height: AppSpacing.lg),
                                sections[2],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < sections.length;
                                index++
                              ) ...[
                                Expanded(child: sections[index]),
                                if (index < sections.length - 1)
                                  const SizedBox(width: AppSpacing.xl),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _directSection() => _SectionCard(
    children: [
      _SectionTitle(
        number: 1,
        title: '오늘은 이것만 직접',
        label: '${_controller.directListTasks.length}개 · 가볍게',
      ),
      const SizedBox(height: AppSpacing.md),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_controller.directListTasks.isEmpty)
            Text(
              '직접 할 일을 모두 가족과 나눴어요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final task in _controller.directListTasks)
              _DirectTaskListItem(task: task),
        ],
      ),
    ],
  );

  Widget _applianceSection() => _SectionCard(
    children: [
      _SectionTitle(
        number: 3,
        title: '가전이 대신합니다',
        label:
            '추천 ${_controller.tasksFor(HouseholdTaskOwner.appliance).length}개',
      ),
      const SizedBox(height: AppSpacing.md),
      if (_controller.applianceConnectionStatus case final status?
          when status != 'connected') ...[
        Text(
          switch (status) {
            'not_configured' => 'ThinQ 연결 설정이 필요해요.',
            'auth_error' => 'ThinQ 연결을 다시 확인해 주세요.',
            _ => '가전 목록을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
          },
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _taskCards(HouseholdTaskOwner.appliance),
      ),
    ],
  );

  Widget _partnerSection() => _SectionCard(
    children: [
      _SectionTitle(
        number: 2,
        title: '가족과 나누기',
        label: '${_controller.remainingShareableCount}개 할일',
      ),
      const SizedBox(height: AppSpacing.md),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '공유할 집안일을 선택해 주세요.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final task in _controller.shareableTasks) ...[
            HouseholdTaskCard(
              task: task,
              selectable: _controller.canShareTask(task),
              trailingLabel: switch (task.status) {
                HouseholdTaskStatus.shared => '공유됨',
                HouseholdTaskStatus.confirmed => '확인됨',
                HouseholdTaskStatus.done => '완료됨',
                _ => null,
              },
              onTap: _controller.canShareTask(task)
                  ? () => _controller.toggleSelection(task.id)
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_controller.shareError != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              title: '공유하지 못했어요',
              message: _controller.shareError,
              tone: InfoBannerTone.danger,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: const ValueKey('household-share-button'),
            label: _controller.sharing
                ? '요청 보내는 중…'
                : _controller.remainingShareableCount == 0 && _controller.shared
                ? '남편에게 공유했어요'
                : '남편에게 공유하기',
            loading: _controller.sharing,
            color: AppColors.accentWarm,
            onPressed: _controller.selectedCount == 0 || _controller.sharing
                ? null
                : _share,
          ),
          if (_controller.shared) ...[
            const SizedBox(height: AppSpacing.lg),
            const _LiveStatusBanner(),
          ],
        ],
      ),
    ],
  );

  List<Widget> _taskCards(HouseholdTaskOwner owner) {
    return [
      for (final task in _controller.tasksFor(owner)) ...[
        HouseholdTaskCard(
          task: task,
          actionLabel: owner == HouseholdTaskOwner.appliance ? '실행' : null,
          onAction: owner == HouseholdTaskOwner.appliance
              ? () => _runAppliance(task)
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  /// 공기청정기는 ThinQ 실기기를 켜고, 그 외 가전은 로컬 실행 이력만 기록한다.
  Future<void> _runAppliance(HouseholdTask task) async {
    if (task.airPurifierDeviceId case final deviceId?) {
      final ok = await _controller.runAirPurifier(deviceId);
      if (!mounted) return;
      await showAppDialog<void>(
        context: context,
        builder: (context) => AppDialog(
          icon: ok ? Icons.check_circle_outline : Icons.error_outline,
          iconColor: ok ? AppColors.success : AppColors.danger,
          title: ok ? '공기청정기를 켰어요' : '공기청정기를 켜지 못했어요',
          content: ok
              ? const SizedBox.shrink()
              : const Text('연결 상태를 확인하고 다시 시도해 주세요.'),
          actions: [
            AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
      return;
    }
    ApplianceExecutionStore.instance.record(
      source: ApplianceExecutionSource.household,
      label: task.title,
    );
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        title: '가전 실행했어요',
        content: const SizedBox.shrink(),
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Future<void> _share() async {
    final selectedCount = _controller.selectedCount;
    final shared = await _controller.shareSelected();
    if (!mounted || !shared) return;
    final requestRoute = RouteNames.partnerRequest(_controller.lastRequestId!);
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.check_circle,
        iconColor: AppColors.success,
        title: '남편에게 공유했어요',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('선택한 $selectedCount개 항목을 요청 카드로 보냈어요.'),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: '파트너 요청 경로 $requestRoute',
              child: const InfoBanner(
                title: '남편 요청함에 도착했어요',
                message: '확인과 완료 상태는 이 화면에 다시 반영돼요.',
                tone: InfoBannerTone.info,
              ),
            ),
          ],
        ),
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }
}

class _DirectTaskListItem extends StatelessWidget {
  const _DirectTaskListItem({required this.task});

  final HouseholdTask task;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('household-direct-list-${task.id}'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: AppColors.categoryHome,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            task.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
    required this.label,
  });
  final int number;
  final String title;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    spacing: AppSpacing.md,
    children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.categoryHome,
        child: Text(
          '$number',
          style: const TextStyle(
            color: AppColors.textInverse,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
      ),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.41,
          ),
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.categoryHome,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _GuideSummaryCard extends StatelessWidget {
  const _GuideSummaryCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
    decoration: BoxDecoration(
      color: AppColors.categoryHome.withValues(alpha: 0.4),
      border: Border.all(color: AppColors.borderSubtle),
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: const Text(
      '오늘의 가사 가이드',
      style: TextStyle(
        color: AppColors.primary900,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.41,
      ),
    ),
  );
}

/// 시안: 섹션마다 따뜻한 갈색 테두리 카드(radius 20)로 묶는다.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.accentWarm),
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.info),
        SizedBox(width: AppSpacing.md),
        Expanded(child: Text('남편의 확인·완료 상태가 요청 Route를 통해 이 화면에 반영돼요')),
      ],
    ),
  );
}
