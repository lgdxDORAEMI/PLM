import 'package:flutter/material.dart';

/// label과 semantic 의미를 유지하는 공통 입력 필드다.
class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}
