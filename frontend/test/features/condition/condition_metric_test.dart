import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/tokens/app_colors.dart';
import 'package:plm_frontend/features/condition/widgets/condition_metric.dart';

void main() {
  testWidgets('기분은 다른 컨디션 항목과 동일한 선택 색상을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ConditionMetric(
                label: '기분',
                value: 5,
                valueLabels: moodLabels,
                onChanged: (_) {},
              ),
              ConditionMetric(
                label: '피로',
                value: 5,
                valueLabels: discomfortLabels,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    for (var index = 1; index <= 5; index++) {
      final moodSegment = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('기분-$index')),
      );
      final fatigueSegment = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('피로-$index')),
      );
      final moodDecoration = moodSegment.decoration! as BoxDecoration;
      final fatigueDecoration = fatigueSegment.decoration! as BoxDecoration;

      expect(moodDecoration.color, AppColors.primary500);
      expect(moodDecoration.color, fatigueDecoration.color);
    }
  });

  testWidgets('낮은 단계의 기분도 다른 항목과 동일한 색상을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConditionMetric(
            label: '기분',
            value: 3,
            valueLabels: moodLabels,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    for (var index = 1; index <= 3; index++) {
      final segment = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('기분-$index')),
      );
      final decoration = segment.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.primary300);
    }
  });
}
