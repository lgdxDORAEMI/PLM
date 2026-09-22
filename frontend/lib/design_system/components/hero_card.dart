import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_elevation.dart';

/// 화면 첫 맥락을 primary 채움 카드로 보여준다(DESIGN_2 §5.1). 홈 주차 히어로·남편 초대 상단에서 쓴다.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: AppColors.primary600,
        // Figma 값 15는 AppRadius에 없는 값이라 여기서만 쓴다.
        borderRadius: BorderRadius.circular(15),
        boxShadow: AppElevation.level3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textInverse,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.38,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.primary50,
              fontSize: 14,
              height: 2,
            ),
          ),
        ],
      ),
    );
  }
}
