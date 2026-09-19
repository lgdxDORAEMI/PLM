class PartnerMorningReport {
  const PartnerMorningReport({
    required this.targetDate,
    required this.pregnancyWeek,
    required this.conditionSummary,
    required this.plannedActivities,
    required this.guideSummaries,
  });

  final DateTime targetDate;
  final int pregnancyWeek;
  final List<String> conditionSummary;
  final List<String> plannedActivities;
  final Map<String, String> guideSummaries;

  /// Backend의 공개 오전 리포트 계약만 파싱하고 원본 프로필 정보는 다루지 않는다.
  factory PartnerMorningReport.fromJson(Map<String, dynamic> json) {
    final targetDate = DateTime.tryParse(json['target_date']?.toString() ?? '');
    final pregnancyWeek = json['pregnancy_week'];
    final conditionSummary = json['condition_summary'];
    final plannedActivities = json['planned_activities'];
    final guideSummaries = json['guide_summaries'];
    if (targetDate == null ||
        pregnancyWeek is! num ||
        conditionSummary is! List ||
        plannedActivities is! List ||
        guideSummaries is! Map) {
      throw const FormatException('오전 리포트 응답 형식이 올바르지 않습니다.');
    }

    return PartnerMorningReport(
      targetDate: targetDate,
      pregnancyWeek: pregnancyWeek.toInt(),
      conditionSummary: conditionSummary.whereType<String>().toList(),
      plannedActivities: plannedActivities.whereType<String>().toList(),
      guideSummaries: guideSummaries.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}
