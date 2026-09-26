import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';

/// Home의 첫 맥락. 초록 머리(주차·주의) + 연한 본문(주차 특징) 2단 카드(Figma 126:612).
/// 본문 문장은 Backend `home.week_notes`·`home.caution`이라 길이가 바뀌므로 높이를 고정하지 않는다.
class PregnancyWeekHero extends StatelessWidget {
  const PregnancyWeekHero({
    super.key,
    required this.userName,
    required this.week,
    this.tips = const [],
    this.caution,
    this.statusMessage,
    this.onRetry,
  });

  final String? userName;
  final int week;
  final List<String> tips;
  final String? caution;
  final String? statusMessage;
  final VoidCallback? onRetry;

  // Figma 값 15는 AppRadius에 없는 값이라 여기서만 쓴다.
  static const _radius = Radius.circular(15);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('home-week-hero'),
      container: true,
      label: userName == null ? '현재 임신 $week주차' : '$userName님, 현재 임신 $week주차',
      // 양옆 4씩 좁은 본문 배경 위에 둥근 초록 머리 카드를 얹어, 머리 아래 모서리 뒤로 본문이 이어져 보이게 한다.
      child: Stack(
        children: [
          const Positioned.fill(
            left: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFECECE8),
                borderRadius: BorderRadius.all(_radius),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F202624),
                    offset: Offset(0, 10),
                    blurRadius: 16,
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary600,
                  border: Border.all(color: AppColors.success),
                  borderRadius: const BorderRadius.all(_radius),
                  // 가까운 진한 그림자 + 넓게 퍼지는 옅은 그림자를 겹쳐 본문 위로 떠 보이게 한다.
                  // spread를 음수로 둬 좁은 본문 양옆으로 그림자가 새지 않게 한다.
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33213D38),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Color(0x3D213D38),
                      offset: Offset(0, 8),
                      blurRadius: 16,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      '임신 $week주차',
                      style: const TextStyle(
                        color: AppColors.textInverse,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.38,
                      ),
                    ),
                    if (caution case final caution?
                        when caution.trim().isNotEmpty)
                      Text(
                        _keepWords(caution.trim()),
                        semanticsLabel: caution.trim(),
                        style: const TextStyle(
                          color: AppColors.primary50,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.7,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                // Figma는 본문이 머리 밑으로 20 겹치고 위 여백 30이라 보이는 간격은 10이다.
                // 가로 20은 본문이 좁아져도 글머리가 제목과 같은 선에 오도록 바깥 기준으로 둔다.
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
                child: tips.isEmpty
                    ? _WeekGuideStatus(message: statusMessage, onRetry: onRetry)
                    : _WeekGuideTips(tips: tips),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekGuideTips extends StatelessWidget {
  const _WeekGuideTips({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tip in tips)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.circle, size: 7, color: AppColors.primary600),
              ),
              Expanded(
                child: Text(
                  _keepWords(tip),
                  semanticsLabel: tip,
                  style: const TextStyle(
                    color: AppColors.primary900,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 시안에 없는 불러오는 중·실패 상태. 같은 본문 영역에 안내 문구와 재시도만 둔다.
class _WeekGuideStatus extends StatelessWidget {
  const _WeekGuideStatus({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message ?? '오늘의 상태부터 확인하고, 필요한 일만 차분히 이어가요.',
          style: const TextStyle(
            color: AppColors.primary700,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary700,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('다시 불러오기'),
          ),
      ],
    );
  }
}

/// Flutter는 한글을 글자 단위로 줄바꿈해 "상담|하세요"처럼 어절이 갈린다.
/// 글자 사이에 word joiner(U+2060)를 넣어 띄어쓰기에서만 줄바꿈되게 한다(CSS keep-all).
String _keepWords(String text) =>
    text.split(' ').map((word) => word.split('').join('⁠')).join(' ');
