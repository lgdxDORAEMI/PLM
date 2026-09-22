import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../profile/data/profile_store.dart';
import '../controllers/planned_activity_controller.dart';
import '../services/planned_activity_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.editing = false, this.service});

  final bool editing;
  final PlannedActivityService? service;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final PlannedActivityController _controller;
  late final TextEditingController _customController;
  late Set<String> _initialSelection;
  bool _allowPop = false;
  bool _handlingBack = false;

  @override
  void initState() {
    super.initState();
    _controller = PlannedActivityController(service: widget.service)
      ..addListener(_refresh);
    _initialSelection = _controller.selected;
    _customController = TextEditingController();
    unawaited(_loadActivities());
  }

  Future<void> _loadActivities() async {
    try {
      await _controller.loadActivities();
      if (mounted) _initialSelection = _controller.selected;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('예정 활동을 불러오지 못했어요.')));
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _customController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !widget.editing || _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && widget.editing) unawaited(_handleBack());
    },
    child: Scaffold(
      appBar: TopAppBar(
        title: widget.editing ? '오늘 할일 수정하기' : '오늘 예정 활동',
        onBack: _handleBack,
        wifeProfileAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            children: [
              Text(
                '오늘 할 집안일이 있나요?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '예정된 일을 알려주면 오늘 컨디션에 맞춰 직접 할 일과 도움받을 일을 나눠드려요.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 92,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: PlannedActivityController.options.length,
                itemBuilder: (context, index) {
                  final activity = PlannedActivityController.options[index];
                  return _ActivityCard(
                    activity: activity,
                    icon: _iconFor(activity),
                    selected: _controller.selected.contains(activity),
                    onTap: () => _controller.toggle(activity),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('목록에 없는 활동', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AppInput(
                key: const ValueKey('custom-activity-input'),
                label: '직접 입력',
                hintText: '예: 베란다 정리',
                controller: _customController,
                textInputAction: TextInputAction.done,
                onSubmitted: _addCustom,
                suffixIcon: IconButton(
                  tooltip: '활동 추가',
                  onPressed: () => _addCustom(_customController.text),
                  icon: const Icon(Icons.add),
                ),
              ),
              if (_customSelections.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final activity in _customSelections)
                      InputChip(
                        label: Text(activity),
                        onDeleted: () => _controller.toggle(activity),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const ValueKey('activity-submit-button'),
                label: _controller.generating
                    ? widget.editing || ProfileStore.instance.awaitsResetRoutine
                          ? '오늘 루틴 만드는 중…'
                          : '저장 중…'
                    : widget.editing
                    ? '수정 완료'
                    : ProfileStore.instance.awaitsResetRoutine
                    ? 'AI 루틴 만들기'
                    : '다음',
                onPressed: _controller.generating ? null : _generate,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<String> get _customSelections => _controller.selected
      .where((value) => !PlannedActivityController.options.contains(value))
      .toList(growable: false);

  void _addCustom(String value) {
    _controller.addCustom(value);
    _customController.clear();
  }

  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_controller.generating) return;
    if (!widget.editing && !ProfileStore.instance.awaitsResetRoutine) {
      try {
        await _controller.saveActivities();
        if (mounted) {
          Navigator.pushReplacementNamed(context, RouteNames.dailyInvite);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('예정 활동을 저장하지 못했어요. 다시 시도해 주세요.')),
          );
        }
      }
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final loadingRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope<void>(
        canPop: false,
        child: AlertDialog(
          title: Text('AI 루틴 생성중...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.lg),
              Text('오늘 컨디션과 예정 활동을 반영하고 있어요.\n약 10~15초 걸릴 수 있어요.'),
            ],
          ),
        ),
      ),
    );
    navigator.push(loadingRoute);
    var generationFailed = false;
    try {
      await _controller.generateRoutine();
    } catch (_) {
      generationFailed = true;
    } finally {
      // The request result, not a timer, controls the loading window lifetime.
      if (navigator.mounted && loadingRoute.isActive) {
        navigator.removeRoute(loadingRoute);
      }
    }
    if (!mounted) return;
    if (generationFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘의 루틴을 만들지 못했어요. 다시 시도해 주세요.')),
      );
      return;
    }
    if (ProfileStore.instance.awaitsResetRoutine) {
      ProfileStore.instance.completeResetRoutine();
    }
    if (widget.editing) {
      await _leaveEditing();
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  bool get _hasUnsavedChanges =>
      _controller.selected.length != _initialSelection.length ||
      !_controller.selected.containsAll(_initialSelection);

  /// Confirm unsaved edits before leaving the activity editor.
  Future<void> _handleBack() async {
    if (_handlingBack || _controller.generating) return;
    if (widget.editing) {
      _handlingBack = true;
      try {
        if (_hasUnsavedChanges) {
          final save = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('변경사항을 저장하시겠어요?'),
              content: const Text('저장하면 오늘의 루틴에 변경한 활동이 반영돼요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('저장 안 함'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장하기'),
                ),
              ],
            ),
          );
          if (!mounted || save == null) return;
          if (save) {
            await _generate();
            return;
          }
        }
        await _leaveEditing();
      } finally {
        _handlingBack = false;
      }
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  Future<void> _leaveEditing() async {
    if (Navigator.canPop(context)) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  IconData _iconFor(String activity) => switch (activity) {
    '장보기' => Icons.shopping_cart_outlined,
    '빨래' => Icons.local_laundry_service_outlined,
    '청소' => Icons.cleaning_services_outlined,
    '설거지' => Icons.countertops_outlined,
    '요리' => Icons.soup_kitchen_outlined,
    '쓰레기 배출' => Icons.delete_outline,
    '침구 정리' => Icons.bed_outlined,
    '화분 관리' => Icons.local_florist_outlined,
    _ => Icons.inventory_2_outlined,
  };
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String activity;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: activity,
    child: AppInkWell(
      key: ValueKey('activity-$activity'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary400 : AppColors.borderSubtle,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary600 : AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(activity, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
