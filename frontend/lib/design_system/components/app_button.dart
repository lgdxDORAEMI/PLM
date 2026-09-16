import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';

enum AppButtonVariant { primary, secondary }

/// 공통 CTA. 화면은 색상·높이·radius를 직접 지정하지 않는다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon), const SizedBox(width: 8), Text(label)],
          );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 52)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    );
    final button = variant == AppButtonVariant.primary
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFFE4E0DE);
                }
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.primary800;
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.primary700;
                }
                return AppColors.primary600;
              }),
            ),
            child: child,
          )
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
