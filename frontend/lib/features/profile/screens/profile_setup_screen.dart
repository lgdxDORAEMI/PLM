import 'package:flutter/material.dart';

import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/selection_card.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_context.dart';
import '../../../routing/route_names.dart';
import '../controllers/profile_setup_controller.dart';
import '../widgets/profile_fields.dart';
import '../widgets/profile_summary.dart';
import '../widgets/profile_wizard_frame.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.mode});

  final ProfileMode mode;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final ProfileSetupController _controller;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _medicalNoteController;

  static const _allergyOptions = ['갑각류', '견과류', '우유', '계란', '밀', '없어요'];
  static const _medicalOptions = ['임신성 당뇨 경계', '빈혈', '고혈압', '조기진통', '역류성 식도염'];

  @override
  void initState() {
    super.initState();
    _controller = ProfileSetupController(mode: widget.mode)
      ..addListener(_onControllerChanged);
    final draft = _controller.draft;
    _heightController = TextEditingController(text: draft.height);
    _weightController = TextEditingController(text: draft.prePregnancyWeight);
    _medicalNoteController = TextEditingController(text: draft.medicalNote);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicalNoteController.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final showBack = _controller.step > 0 || widget.mode == ProfileMode.edit;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: TopAppBar(
          title: widget.mode == ProfileMode.create ? '프로필 설정' : '프로필 수정',
          showBack: showBack,
          onBack: _handleBack,
          wifeProfileAction: widget.mode == ProfileMode.edit,
        ),
        body: SafeArea(
          top: false,
          child: _controller.isSummary
              ? ProfileSummary(
                  draft: _controller.draft,
                  onEditStep: _controller.editStep,
                  onComplete: _complete,
                  completeLabel: widget.mode == ProfileMode.create
                      ? '완료하고 시작하기'
                      : '수정 완료',
                )
              : _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_controller.step) {
      0 => ProfileWizardFrame(
        step: 0,
        title: '출산예정일을 알려주세요',
        description: '입력한 정보는 언제든 수정할 수 있어요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        child: Column(
          children: [
            ProfileDateField(
              key: const Key('due-date-field'),
              label: '출산예정일',
              value: _controller.draft.dueDate,
              onTap: () => _selectDate(isDueDate: true),
              helperText: '아직 모르겠다면 마지막 생리 시작일로 계산해 드려요.',
            ),
            const SizedBox(height: AppSpacing.xl),
            ProfileDateField(
              key: const Key('last-period-field'),
              label: '마지막 생리 시작일',
              value: _controller.draft.lastPeriodDate,
              onTap: () => _selectDate(isDueDate: false),
            ),
          ],
        ),
      ),
      1 => ProfileWizardFrame(
        step: 1,
        title: '임신 전 신장·체중을 알려주세요',
        description: '관절 부담 기준과 맞춤 가이드를 계산할 때 사용해요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        child: _BodyFields(
          heightController: _heightController,
          weightController: _weightController,
          onHeightChanged: _controller.updateHeight,
          onWeightChanged: _controller.updateWeight,
        ),
      ),
      2 => ProfileWizardFrame(
        step: 2,
        title: '첫 출산이신가요?',
        description: '경산이면 회복 속도와 부담 기준이 달라져요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        continueEnabled: _controller.draft.isFirstPregnancy != null,
        child: Column(
          children: [
            SelectionCard(
              label: '초산이에요',
              selected: _controller.draft.isFirstPregnancy == true,
              onTap: () => _controller.updateFirstPregnancy(true),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectionCard(
              label: '경산이에요',
              selected: _controller.draft.isFirstPregnancy == false,
              onTap: () => _controller.updateFirstPregnancy(false),
            ),
          ],
        ),
      ),
      3 => ProfileWizardFrame(
        step: 3,
        title: '아기는 몇 명인가요?',
        description: '다태 임신이면 체중 부담 기준을 더 낮게 잡아요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        continueEnabled: _controller.draft.isMultiplePregnancy != null,
        child: Column(
          children: [
            SelectionCard(
              label: '한 명이에요 (단태)',
              selected: _controller.draft.isMultiplePregnancy == false,
              onTap: () => _controller.updateMultiplePregnancy(false),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectionCard(
              label: '둘 이상이에요 (다태)',
              selected: _controller.draft.isMultiplePregnancy == true,
              onTap: () => _controller.updateMultiplePregnancy(true),
            ),
          ],
        ),
      ),
      4 => ProfileWizardFrame(
        step: 4,
        title: '알레르기가 있나요?',
        description: '식사 가이드에서 해당 재료를 빼고 추천해요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileChoiceGrid(
              options: _allergyOptions,
              selectedValues: _controller.draft.allergies,
              onSelected: _controller.toggleAllergy,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '해당 없으면 선택하지 않고 바로 다음으로 넘어가세요.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      5 => ProfileWizardFrame(
        step: 5,
        title: '병원에서 주의받은 게 있나요?',
        description: '혈당·혈압에 맞춰 메뉴와 활동을 조정해요.',
        validationMessage: _controller.validationMessage,
        onContinue: _continue,
        continueLabel: _continueLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileChoiceGrid(
              options: _medicalOptions,
              selectedValues: _controller.draft.medicalConditions,
              onSelected: _controller.toggleMedicalCondition,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppInput(
              label: '그 외 들은 말이 있다면 적어주세요',
              controller: _medicalNoteController,
              hintText: '예) 체중이 조금 빠르게 늘고 있다고 들었어요.',
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: _controller.updateMedicalNote,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '적어주시면 식사·활동 가이드에 바로 반영돼요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    _controller.continueToNextStep();
  }

  String get _continueLabel => _controller.editingFromSummary ? '저장' : '다음';

  /// 날짜 종류에 맞는 범위를 제한해 논리적으로 잘못된 값을 방지한다.
  Future<void> _selectDate({required bool isDueDate}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final currentValue = isDueDate
        ? _controller.draft.dueDate
        : _controller.draft.lastPeriodDate;
    final firstDate = isDueDate
        ? today
        : today.subtract(const Duration(days: 300));
    final lastDate = isDueDate ? today.add(const Duration(days: 300)) : today;
    final selected = await showDatePicker(
      context: context,
      initialDate: currentValue ?? today,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isDueDate ? '출산예정일 선택' : '마지막 생리 시작일 선택',
    );
    if (selected == null) return;
    isDueDate
        ? _controller.updateDueDate(selected)
        : _controller.updateLastPeriodDate(selected);
  }

  Future<void> _handleBack() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_controller.moveBack()) return;
    if (_controller.isDirty && !await _confirmDiscard()) return;
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(
        context,
        widget.mode == ProfileMode.edit
            ? RouteNames.wifeMenu
            : RouteNames.entry,
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('입력을 그만할까요?'),
            content: const Text('아직 저장하지 않은 내용은 사라져요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('계속 입력'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('나가기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _complete() {
    _controller.markSaved();
    if (widget.mode == ProfileMode.create) {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeMenu);
    }
  }
}

class _BodyFields extends StatelessWidget {
  const _BodyFields({
    required this.heightController,
    required this.weightController,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  final TextEditingController heightController;
  final TextEditingController weightController;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<String> onWeightChanged;

  @override
  Widget build(BuildContext context) {
    final height = ProfileUnitInput(
      label: '신장',
      unit: 'cm',
      controller: heightController,
      onChanged: onHeightChanged,
    );
    final weight = ProfileUnitInput(
      label: '체중 (임신 전)',
      unit: 'kg',
      controller: weightController,
      textInputAction: TextInputAction.done,
      onChanged: onWeightChanged,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: height),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: weight),
      ],
    );
  }
}
