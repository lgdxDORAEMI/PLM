import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/tokens/app_colors.dart';
import 'package:plm_frontend/features/condition/widgets/condition_metric.dart';

void main() {
  testWidgets('기분 5단계는 동일한 primary 계열의 톤 차이로 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConditionMetric(
            label: '기분',
            value: 5,
            valueLabels: moodLabels,
            positiveScale: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    const expectedColors = [
      AppColors.primary200,
      AppColors.primary300,
      AppColors.primary400,
      AppColors.primary500,
      AppColors.primary600,
    ];
    for (var index = 0; index < expectedColors.length; index++) {
      final container = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('기분-${index + 1}')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, expectedColors[index]);
    }
  });
}
