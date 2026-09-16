import 'package:flutter/material.dart';

/// DESIGN.md type scale. Theme에서 색상을 결합해 사용한다.
abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 36,
    height: 46 / 36,
    fontWeight: FontWeight.w700,
  );
  static const heading1 = TextStyle(
    fontSize: 28,
    height: 38 / 28,
    fontWeight: FontWeight.w700,
  );
  static const heading2 = TextStyle(
    fontSize: 22,
    height: 31 / 22,
    fontWeight: FontWeight.w700,
  );
  static const heading3 = TextStyle(
    fontSize: 18,
    height: 27 / 18,
    fontWeight: FontWeight.w600,
  );
  static const bodyLarge = TextStyle(
    fontSize: 17,
    height: 27 / 17,
    fontWeight: FontWeight.w500,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 24 / 15,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
  );

  /// 기존 Feature가 새 scale로 자연스럽게 이동하도록 제공하는 호환 별칭이다.
  static const title1 = heading1;
  static const title2 = heading2;
  static const heading = heading3;
  static const body1 = bodyLarge;
  static const body2 = body;
}
