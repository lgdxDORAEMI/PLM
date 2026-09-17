/// Profile Wizard에서만 유지되는 저장 전 입력값이다.
class ProfileDraft {
  const ProfileDraft({
    this.dueDate,
    this.lastPeriodDate,
    this.height,
    this.prePregnancyWeight,
    this.isFirstPregnancy,
    this.isMultiplePregnancy,
    this.allergies = const <String>{},
    this.medicalConditions = const <String>{},
    this.medicalNote = '',
  });

  factory ProfileDraft.mockEdit() {
    final today = DateTime.now();
    return ProfileDraft(
      dueDate: DateTime(today.year, today.month + 4, 20),
      height: '165',
      prePregnancyWeight: '55',
      isFirstPregnancy: true,
      isMultiplePregnancy: false,
      allergies: const {'갑각류'},
      medicalConditions: const {'임신성 당뇨 경계'},
      medicalNote: '체중이 조금 빠르게 늘고 있다고 들었어요.',
    );
  }

  final DateTime? dueDate;
  final DateTime? lastPeriodDate;
  final String? height;
  final String? prePregnancyWeight;
  final bool? isFirstPregnancy;
  final bool? isMultiplePregnancy;
  final Set<String> allergies;
  final Set<String> medicalConditions;
  final String medicalNote;

  /// Bootstrap은 실제 필수 Profile 값이 모두 유효할 때만 완료 사용자로 판정한다.
  bool get isComplete {
    final parsedHeight = double.tryParse(height ?? '');
    final parsedWeight = double.tryParse(prePregnancyWeight ?? '');
    return effectiveDueDate != null &&
        parsedHeight != null &&
        parsedHeight >= 100 &&
        parsedHeight <= 220 &&
        parsedWeight != null &&
        parsedWeight >= 30 &&
        parsedWeight <= 250 &&
        isFirstPregnancy != null &&
        isMultiplePregnancy != null;
  }

  /// 병원에서 확정한 예정일이 없을 때만 마지막 생리일+280일을 사용한다.
  DateTime? get effectiveDueDate =>
      dueDate ?? lastPeriodDate?.add(const Duration(days: 280));

  /// 저장된 예정일을 기준으로 현재 임신 주수를 계산한다.
  int? pregnancyWeekAt(DateTime date) {
    final due = effectiveDueDate;
    if (due == null) return null;
    final dueDay = DateTime.utc(due.year, due.month, due.day);
    final today = DateTime.utc(date.year, date.month, date.day);
    final daysSinceLmp = 280 - dueDay.difference(today).inDays;
    return (daysSinceLmp ~/ 7).clamp(0, 42);
  }

  ProfileDraft copyWith({
    DateTime? dueDate,
    DateTime? lastPeriodDate,
    bool clearDueDate = false,
    bool clearLastPeriodDate = false,
    String? height,
    String? prePregnancyWeight,
    bool? isFirstPregnancy,
    bool? isMultiplePregnancy,
    Set<String>? allergies,
    Set<String>? medicalConditions,
    String? medicalNote,
  }) {
    return ProfileDraft(
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      lastPeriodDate: clearLastPeriodDate
          ? null
          : lastPeriodDate ?? this.lastPeriodDate,
      height: height ?? this.height,
      prePregnancyWeight: prePregnancyWeight ?? this.prePregnancyWeight,
      isFirstPregnancy: isFirstPregnancy ?? this.isFirstPregnancy,
      isMultiplePregnancy: isMultiplePregnancy ?? this.isMultiplePregnancy,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medicalNote: medicalNote ?? this.medicalNote,
    );
  }
}
