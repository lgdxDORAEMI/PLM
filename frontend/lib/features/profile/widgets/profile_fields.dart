import 'package:flutter/material.dart';

import '../../../design_system/components/app_input.dart';
import '../../../design_system/components/selection_card.dart';
import '../../../design_system/tokens/app_spacing.dart';

/// 날짜 선택기를 공통 Input 모양으로 연결하는 Profile 전용 Field다.
class ProfileDateField extends StatefulWidget {
  const ProfileDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.helperText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? helperText;

  @override
  State<ProfileDateField> createState() => _ProfileDateFieldState();
}

class _ProfileDateFieldState extends State<ProfileDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formattedValue);
  }

  @override
  void didUpdateWidget(covariant ProfileDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _formattedValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _formattedValue {
    final value = widget.value;
    return value == null
        ? ''
        : '${value.year}. ${value.month.toString().padLeft(2, '0')}. '
              '${value.day.toString().padLeft(2, '0')}.';
  }

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: widget.label,
      controller: _controller,
      hintText: 'YYYY.MM.DD',
      helperText: widget.helperText,
      readOnly: true,
      onTap: widget.onTap,
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    );
  }
}

/// 숫자 입력과 단위를 한 Field 안에서 일관되게 보여준다.
class ProfileUnitInput extends StatelessWidget {
  const ProfileUnitInput({
    super.key,
    required this.label,
    required this.unit,
    required this.controller,
    required this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final String unit;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: label,
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      onChanged: onChanged,
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Center(widthFactor: 1, child: Text(unit)),
      ),
    );
  }
}

/// 3개 이상 선택지를 반응형 2열 Grid의 SelectionCard로 표시한다.
class ProfileChoiceGrid extends StatelessWidget {
  const ProfileChoiceGrid({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onSelected,
  });

  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: options
              .map(
                (option) => SizedBox(
                  width: itemWidth,
                  child: SelectionCard(
                    label: option,
                    selected: selectedValues.contains(option),
                    onTap: () => onSelected(option),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
