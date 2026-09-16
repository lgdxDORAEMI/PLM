/// Today Care 화면에서 사용하는 당일 local 입력값이다.
class ConditionDraft {
  const ConditionDraft({
    this.nausea = 4,
    this.waistPain = 4,
    this.pelvisPain = 3,
    this.legPain = 2,
    this.wristPain = 1,
    this.fatigue = 4,
    this.mood = 4,
  });

  final int nausea;
  final int waistPain;
  final int pelvisPain;
  final int legPain;
  final int wristPain;
  final int fatigue;
  final int mood;

  ConditionDraft copyWith({
    int? nausea,
    int? waistPain,
    int? pelvisPain,
    int? legPain,
    int? wristPain,
    int? fatigue,
    int? mood,
  }) {
    return ConditionDraft(
      nausea: nausea ?? this.nausea,
      waistPain: waistPain ?? this.waistPain,
      pelvisPain: pelvisPain ?? this.pelvisPain,
      legPain: legPain ?? this.legPain,
      wristPain: wristPain ?? this.wristPain,
      fatigue: fatigue ?? this.fatigue,
      mood: mood ?? this.mood,
    );
  }
}
