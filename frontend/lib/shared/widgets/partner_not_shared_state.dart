import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';

/// 09-29: 남편 화면. 아내가 초기화 후 아직 초대를 확인하지 않아 볼 수 있는 정보가 없다.
class PartnerNotSharedState extends StatelessWidget {
  const PartnerNotSharedState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('partner-not-shared'),
    child: Text(
      '아내의 프로필 정보가 없습니다',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textDisabled,
        fontSize: 16,
        height: 1.5,
      ),
    ),
  );
}
