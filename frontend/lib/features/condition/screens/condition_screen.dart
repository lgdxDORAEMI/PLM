import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/section_header.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../controllers/today_care_controller.dart';
import '../widgets/condition_metric.dart';
import '../widgets/pain_metric_card.dart';

class ConditionScreen extends StatefulWidget {
  const ConditionScreen({super.key, required this.mode});

  final ConditionMode mode;

  @override
  State<ConditionScreen> createState() => _ConditionScreenState();
}

class _ConditionScreenState extends State<ConditionScreen> {
  late final TodayCareController _controller;
  bool _allowPop = false;
  bool _saving = false;

  bool get _isEditing => widget.mode == ConditionMode.edit;

  @override
  void initState() {
    super.initState();
    _controller = TodayCareController()..addListener(_refresh);
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
    final draft = _controller.draft;
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: TopAppBar(
          title: '오늘의 컨디션',
          onBack: _handleBack,
          wifeProfileAction: true,
        ),
        body: SafeArea(
          top: false,
          child: ResponsivePageContent.form(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TodayCareIntro(),
                  const SizedBox(height: AppSpacing.xxl),
                  ConditionMetric(
                    label: '입덧',
                    value: draft.nausea,
                    valueLabels: discomfortLabels,
                    onChanged: _controller.updateNausea,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(
                    title: '신체 통증',
                    description: '부위별로 알려주세요',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PainMetricCard(
                    label: '허리',
                    value: draft.waistPain,
                    onChanged: _controller.updateWaistPain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PainMetricCard(
                    label: '골반',
                    value: draft.pelvisPain,
                    onChanged: _controller.updatePelvisPain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PainMetricCard(
                    label: '다리',
                    value: draft.legPain,
                    onChanged: _controller.updateLegPain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PainMetricCard(
                    label: '손목',
                    value: draft.wristPain,
                    onChanged: _controller.updateWristPain,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ConditionMetric(
                    label: '피로',
                    value: draft.fatigue,
                    valueLabels: discomfortLabels,
                    onChanged: _controller.updateFatigue,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ConditionMetric(
                    label: '기분',
                    value: draft.mood,
                    valueLabels: moodLabels,
                    onChanged: _controller.updateMood,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppButton(
                    key: const ValueKey('today-care-submit-button'),
                    label: _isEditing ? '수정 완료' : '다음',
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 화면 입력값을 메모리에 보관한 뒤 ROUTE_MAP의 다음 화면으로 이동한다.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _controller.save();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        _isEditing ? RouteNames.wifeHome : RouteNames.activity,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('컨디션을 저장하지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleBack() async {
    if (_controller.isDirty) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('입력을 그만할까요?'),
          content: const Text('변경한 컨디션은 저장되지 않아요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 입력'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (shouldLeave != true || !mounted) return;
    }
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }
}

class _TodayCareIntro extends StatelessWidget {
  const _TodayCareIntro();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘 몸 상태는 어때요?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '10초면 끝나요 · 오늘 · 임신 28주차',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
