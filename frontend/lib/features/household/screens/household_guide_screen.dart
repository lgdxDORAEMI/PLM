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
                                const SizedBox(height: AppSpacing.xl),
                                sections[1],
                                const SizedBox(height: AppSpacing.xl),
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
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        _controller.shared
                            ? '오늘은 허리 통증이 있어요. 무리한 일은 가족과 나눠요.'
                            : '오늘은 허리 통증이 있는 날이에요. 가전 실행 대신 부담을 줄이는 방법을 추천해요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _directSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _applianceSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _partnerSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionTitle(
        number: 2,
        title: '가족과 나누기',
        label: '${_controller.shareableTasks.length}개 할일',
      ),
      const SizedBox(height: AppSpacing.md),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '공유할 집안일을 선택해 주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final task in _controller.shareableTasks) ...[
            HouseholdTaskCard(
              task: task,
              selectable: true,
              onTap: _controller.shared
                  ? null
                  : () => _controller.toggleSelection(task.id),
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
                : _controller.shared
                ? '남편에게 공유했어요'
                : '남편에게 공유하기',
            loading: _controller.sharing,
            onPressed:
                _controller.selectedCount == 0 ||
                    _controller.shared ||
                    _controller.sharing
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

  /// 실제 기기 제어 없이 오늘의 로컬 실행 이력만 기록한다.
  Future<void> _runAppliance(HouseholdTask task) async {
    ApplianceExecutionStore.instance.record(
      source: ApplianceExecutionSource.household,
      label: task.title,
    );
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        title: '가전 실행을 기록했어요',
        message: '${task.title}\n오늘의 가전 실행 내역에 반영했어요. 실제 기기는 작동하지 않았어요.',
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Future<void> _share() async {
    await _controller.shareSelected();
    if (!mounted || !_controller.shared) return;
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
            Text('선택한 ${_controller.selectedCount}개 항목을 요청 카드로 보냈어요.'),
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
        Expanded(child: Text(task.title)),
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
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.categoryHome,
        foregroundColor: AppColors.textInverse,
        child: Text('$number'),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.categoryHome),
      ),
    ],
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
