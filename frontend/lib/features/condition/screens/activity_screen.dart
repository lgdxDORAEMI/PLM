import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/planned_activity_controller.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final PlannedActivityController _controller;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _controller = PlannedActivityController()..addListener(_refresh);
    _customController = TextEditingController();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(
      title: '오늘 예정 활동',
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
            InfoBanner(
              title: _controller.selected.isEmpty
                  ? '예정 활동이 없어도 괜찮아요'
                  : '${_controller.selected.length}개 활동을 반영할게요',
              message: '실제 AI 호출 없이 Mock 루틴을 생성합니다.',
              tone: InfoBannerTone.info,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: const ValueKey('activity-submit-button'),
              label: _controller.generating ? '오늘 루틴 만드는 중…' : '오늘 루틴 만들기',
              onPressed: _controller.generating ? null : _generate,
            ),
          ],
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
    await _controller.generateRoutine();
    if (mounted) {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
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
    child: InkWell(
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
