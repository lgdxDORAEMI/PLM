import 'package:flutter/material.dart';

import '../tokens/app_breakpoints.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Mobile에서는 bottom sheet, Desktop에서는 폭이 제한된 modal panel을 제공한다.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.modal),
      ),
    ),
    builder: builder,
  );
}

class AppBottomSheetFrame extends StatelessWidget {
  const AppBottomSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= AppBreakpoints.tablet
            ? AppSpacing.xxl
            : AppSpacing.xl;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            keyboardInset + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(description!),
              ],
              const SizedBox(height: AppSpacing.xl),
              child,
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        );
      },
    );
  }
}
