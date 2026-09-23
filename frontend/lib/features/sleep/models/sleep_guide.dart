enum SleepEnvironmentType { light, temperature, humidity, sound, purifier }

class SleepEnvironmentSetting {
  const SleepEnvironmentSetting({
    required this.type,
    required this.label,
    required this.value,
    required this.options,
    String? recommendedValue,
  }) : recommendedValue = recommendedValue ?? value;

  final SleepEnvironmentType type;
  final String label;
  final String value;
  final List<String> options;

  /// AI 루틴이 최초로 추천한 값 — 사용자가 값을 바꿔 실행해도 이 값은 그대로 유지된다.
  final String recommendedValue;

  SleepEnvironmentSetting copyWith({String? value}) {
    return SleepEnvironmentSetting(
      type: type,
      label: label,
      value: value ?? this.value,
      options: options,
      recommendedValue: recommendedValue,
    );
  }
}

class SleepGuideData {
  const SleepGuideData({
    this.itemId,
    required this.summaryTitle,
    required this.summary,
    required this.recommendedBedtime,
    required this.environments,
    required this.tips,
  });

  final String? itemId;
  final String summaryTitle;
  final String summary;
  final String recommendedBedtime;
  final List<SleepEnvironmentSetting> environments;
  final List<String> tips;
}
