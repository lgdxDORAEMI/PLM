import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import 'condition_metric.dart';

/// 신체 부위별 통증 입력을 표준 Card 안에 배치한다.
class PainMetricCard extends StatelessWidget {
  const PainMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ConditionMetric(
        label: label,
        value: value,
        valueLabels: discomfortLabels,
        onChanged: onChanged,
      ),
    );
  }
}
