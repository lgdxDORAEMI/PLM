enum SleepEnvironmentType { light, temperature, humidity, sound, purifier }

class SleepEnvironmentSetting {
  const SleepEnvironmentSetting({
    required this.type,
    required this.label,
    required this.value,
    required this.options,
    required this.selected,
  });

  final SleepEnvironmentType type;
  final String label;
  final String value;
  final List<String> options;
  final bool selected;

  SleepEnvironmentSetting copyWith({String? value, bool? selected}) {
    return SleepEnvironmentSetting(
      type: type,
      label: label,
      value: value ?? this.value,
      options: options,
      selected: selected ?? this.selected,
    );
  }
}

class SleepGuideData {
  const SleepGuideData({
    required this.summaryTitle,
    required this.summary,
    required this.recommendedBedtime,
    required this.environments,
    required this.tips,
  });

  final String summaryTitle;
  final String summary;
  final String recommendedBedtime;
  final List<SleepEnvironmentSetting> environments;
  final List<String> tips;
}
