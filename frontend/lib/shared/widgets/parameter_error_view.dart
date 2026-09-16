import 'package:flutter/material.dart';

import '../../design_system/components/app_state_view.dart';

/// 잘못된 date/requestId를 임의 값으로 대체하지 않고 안전한 복귀를 제공한다.
class ParameterErrorView extends StatelessWidget {
  const ParameterErrorView({
    super.key,
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: '정보를 찾을 수 없어요',
      message: message,
      retryLabel: '안전한 화면으로 돌아가기',
      onRetry: onBack,
    );
  }
}
