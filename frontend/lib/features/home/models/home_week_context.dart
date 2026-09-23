class HomeWeekContext {
  const HomeWeekContext({
    required this.week,
    required this.notes,
    required this.caution,
  });

  factory HomeWeekContext.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['week_notes'];
    return HomeWeekContext(
      week: (json['week'] as num?)?.toInt(),
      notes: rawNotes is List
          ? rawNotes.whereType<String>().toList(growable: false)
          : const [],
      caution: json['caution'] as String?,
    );
  }

  final int? week;
  final List<String> notes;
  final String? caution;
}
