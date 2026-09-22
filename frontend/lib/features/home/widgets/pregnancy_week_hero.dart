import 'package:flutter/material.dart';

import '../../../design_system/components/hero_card.dart';

/// Home의 첫 맥락을 장식보다 정보 위계 중심으로 전달한다.
class PregnancyWeekHero extends StatelessWidget {
  const PregnancyWeekHero({
    super.key,
    required this.userName,
    required this.week,
  });

  final String? userName;
  final int week;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: userName == null ? '현재 임신 $week주차' : '$userName님, 현재 임신 $week주차',
      child: HeroCard(
        title: '임신 $week주차',
        description: '오늘의 상태부터 확인하고, 필요한 일만 차분히 이어가요.',
      ),
    );
  }
}
