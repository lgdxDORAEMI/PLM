class PartnerMorningReport {
  const PartnerMorningReport({
    required this.targetDate,
    required this.pregnancyWeek,
    required this.conditionSummary,
    required this.plannedActivities,
    required this.guideSummaries,
    this.conditionScores = const [],
  });

  final DateTime targetDate;
  final int pregnancyWeek;
  final List<String> conditionSummary;
  final List<String> plannedActivities;
  final Map<String, String> guideSummaries;

  /// 아내가 입력한 항목별 1~5점. 필드가 없는 구버전 응답이면 비어 있고 화면은 목록을 숨긴다.
  final List<({String label, int score})> conditionScores;

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
      conditionScores: [
        for (final item
            in (json['condition_scores'] as List?)?.whereType<Map>() ??
                const <Map>[])
          if (item['label'] is String && item['score'] is num)
            (
              label: item['label'] as String,
              score: (item['score'] as num).toInt().clamp(1, 5),
            ),
      ],
    );
  }
}
