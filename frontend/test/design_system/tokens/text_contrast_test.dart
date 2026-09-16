import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/tokens/app_colors.dart';

void main() {
  test('기본 텍스트 토큰은 주요 밝은 배경에서 4.5:1 이상 대비를 유지한다', () {
    for (final foreground in [
      AppColors.textPrimary,
      AppColors.textSecondary,
      AppColors.textTertiary,
    ]) {
      for (final background in [AppColors.canvas, AppColors.surface]) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}

/// WCAG 상대 휘도로 텍스트와 기본 배경의 대비를 계산한다.
double _contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
