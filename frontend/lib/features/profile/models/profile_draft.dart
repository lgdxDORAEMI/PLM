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

  ProfileDraft copyWith({
    DateTime? dueDate,
    DateTime? lastPeriodDate,
    String? height,
    String? prePregnancyWeight,
    bool? isFirstPregnancy,
    bool? isMultiplePregnancy,
    Set<String>? allergies,
    Set<String>? medicalConditions,
    String? medicalNote,
  }) {
    return ProfileDraft(
      dueDate: dueDate ?? this.dueDate,
      lastPeriodDate: lastPeriodDate ?? this.lastPeriodDate,
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
