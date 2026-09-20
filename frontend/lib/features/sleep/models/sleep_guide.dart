enum SleepEnvironmentType { light, temperature, humidity, sound, purifier }

class SleepEnvironmentSetting {
  const SleepEnvironmentSetting({
    required this.type,
    required this.label,
    required this.value,
    required this.options,
  });

  final SleepEnvironmentType type;
  final String label;
  final String value;
  final List<String> options;

  SleepEnvironmentSetting copyWith({String? value}) {
    return SleepEnvironmentSetting(
      type: type,
      label: label,
      value: value ?? this.value,
      options: options,
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
