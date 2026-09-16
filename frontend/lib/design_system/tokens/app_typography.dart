import 'package:flutter/material.dart';

/// DESIGN.md type scale. Theme에서 색상을 결합해 사용한다.
abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 28,
    height: 38 / 28,
    fontWeight: FontWeight.w700,
  );
  static const title1 = TextStyle(
    fontSize: 24,
    height: 34 / 24,
    fontWeight: FontWeight.w700,
  );
  static const title2 = TextStyle(
    fontSize: 20,
    height: 29 / 20,
    fontWeight: FontWeight.w700,
  );
  static const heading = TextStyle(
    fontSize: 18,
    height: 27 / 18,
    fontWeight: FontWeight.w700,
  );
  static const body1 = TextStyle(
    fontSize: 16,
    height: 25 / 16,
    fontWeight: FontWeight.w400,
  );
  static const body2 = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 19 / 13,
    fontWeight: FontWeight.w600,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
}
