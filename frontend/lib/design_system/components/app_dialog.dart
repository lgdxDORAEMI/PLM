import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_button.dart';

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
}

/// 결과와 확인 Modal에 공통으로 사용하는 접근 가능한 dialog surface다.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    this.iconColor,
  }) : assert(message != null || content != null);

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final Color? iconColor;
  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, color: iconColor ?? AppColors.primary600, size: 40),
      title: Text(title),
      content: content ?? Text(message!),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        if (actions.length == 1)
          AppButton(
            label: actions.first.label,
            variant: actions.first.variant,
            onPressed: actions.first.onPressed,
          )
        else
          Row(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: actions[index].label,
                    variant: actions[index].variant,
                    onPressed: actions[index].onPressed,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: builder,
  );
}
