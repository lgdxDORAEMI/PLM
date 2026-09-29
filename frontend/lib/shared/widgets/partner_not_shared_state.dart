import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';

/// 09-29: 남편 화면. 아내가 초기화 후 아직 초대를 확인하지 않아 볼 수 있는 정보가 없다.
class PartnerNotSharedState extends StatelessWidget {
  const PartnerNotSharedState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('partner-not-shared'),
    child: Text(
      '아내가 아직 기록을 공유하지 않았습니다.\n아내 화면의 남편 초대에서 연결을 다시 확인해 주세요.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textDisabled,
        fontSize: 16,
        height: 1.5,
      ),
    ),
  );
}
