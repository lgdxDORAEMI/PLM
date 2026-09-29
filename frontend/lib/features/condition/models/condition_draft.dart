/// Today Care 화면에서 사용하는 당일 local 입력값이다.
class ConditionDraft {
  // 09-29 QA: 최초 진입·초기화 후 화면 값은 모두 1(괜찮아요)로 시작한다.
  // mood는 화면에 없고 API 필수값이라 기존 기본값 4를 유지한다.
  const ConditionDraft({
    this.nausea = 1,
    this.waistPain = 1,
    this.pelvisPain = 1,
    this.legPain = 1,
    this.wristPain = 1,
    this.fatigue = 1,
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
