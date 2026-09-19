import 'package:flutter/material.dart';

import '../../design_system/components/app_state_view.dart';

/// 실제 데이터 공급자가 설정되지 않은 화면의 공통 빈 상태다.
class IntegrationRequiredState extends StatelessWidget {
  const IntegrationRequiredState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(title: '연동이필요합니다', message: message ?? '연결된 데이터가 없습니다.');
}
