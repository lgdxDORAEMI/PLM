import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_spacing.dart';

/// 루틴 생성 요청이 끝날 때까지 닫을 수 없는 로딩창을 띄운다. 실패는 호출자에게 그대로 던진다.
Future<void> runWithRoutineGeneratingDialog(
  BuildContext context,
  Future<void> Function() generate,
) async {
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
  try {
    await generate();
  } finally {
    // The request result, not a timer, controls the loading window lifetime.
    if (navigator.mounted && loadingRoute.isActive) {
      navigator.removeRoute(loadingRoute);
    }
  }
}
