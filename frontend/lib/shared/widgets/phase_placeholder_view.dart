import 'package:flutter/material.dart';

import '../../design_system/components/app_state_view.dart';

/// 현재 범위 밖 기능을 실행 가능한 기능처럼 보이지 않게 안내한다.
class PhasePlaceholderView extends StatelessWidget {
  const PhasePlaceholderView({
    super.key,
    required this.title,
    required this.message,
    this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: Icons.construction_outlined,
      actionLabel: onBack == null ? null : '돌아가기',
      onAction: onBack,
    );
  }
}
