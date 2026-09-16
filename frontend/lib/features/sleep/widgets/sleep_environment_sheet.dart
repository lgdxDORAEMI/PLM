import 'package:flutter/material.dart';

import '../../../design_system/components/app_bottom_sheet.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_input.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/sleep_guide.dart';

class SleepEnvironmentSheet extends StatefulWidget {
  const SleepEnvironmentSheet({
    super.key,
    required this.setting,
    required this.onApply,
  });

  final SleepEnvironmentSetting setting;
  final ValueChanged<String> onApply;

  @override
  State<SleepEnvironmentSheet> createState() => _SleepEnvironmentSheetState();
}

class _SleepEnvironmentSheetState extends State<SleepEnvironmentSheet> {
  late String _selectedValue;
  late final TextEditingController _customController;
  String? _errorText;

  bool get _supportsCustom =>
      widget.setting.type == SleepEnvironmentType.temperature ||
      widget.setting.type == SleepEnvironmentType.humidity;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.setting.value;
    _customController = TextEditingController();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetFrame(
      title: widget.setting.label,
      description:
          '현재 설정 · ${widget.setting.value}\nMVP에서는 기기 제어 없이 추천값만 저장해요.',
      action: AppButton(
        key: ValueKey('sleep-apply-${widget.setting.type.name}'),
        label: '적용하기',
        onPressed: _apply,
      ),
      child: Column(
        children: [
          for (final option in widget.setting.options)
            RadioGroup<String>(
              groupValue: _selectedValue,
              onChanged: (value) {
                if (value != null) setState(() => _selectedValue = value);
              },
              child: RadioListTile<String>(
                key: ValueKey(
                  'sleep-option-${widget.setting.type.name}-$option',
                ),
                value: option,
                title: Text(
                  option == widget.setting.value ? '$option (권장)' : option,
                ),
                activeColor: AppColors.categorySleep,
              ),
            ),
          if (_supportsCustom) ...[
            const SizedBox(height: AppSpacing.md),
            AppInput(
              key: ValueKey('sleep-custom-${widget.setting.type.name}'),
              label: '직접 입력',
              hintText: widget.setting.type == SleepEnvironmentType.temperature
                  ? '0~40°C'
                  : '0~100%',
              controller: _customController,
              keyboardType: TextInputType.number,
              errorText: _errorText,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 직접 입력 범위를 검증한 뒤 local 추천 상태에만 반영한다.
  void _apply() {
    final custom = _customController.text.trim();
    var value = _selectedValue;
    if (_supportsCustom && custom.isNotEmpty) {
      final number = int.tryParse(custom);
      final max = widget.setting.type == SleepEnvironmentType.temperature
          ? 40
          : 100;
      if (number == null || number < 0 || number > max) {
        setState(() => _errorText = '0~$max 사이 숫자를 입력해 주세요.');
        return;
      }
      value = widget.setting.type == SleepEnvironmentType.temperature
          ? '$number°C'
          : '$number%';
    }
    widget.onApply(value);
    Navigator.pop(context);
  }
}
