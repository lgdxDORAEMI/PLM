enum MealPeriod { breakfast, lunch, dinner, snack }

/// 시간대별 고정 구간(06~12 아침 · 12~16 점심 · 16~21 저녁 · 21~06 밤)으로 현재
/// 끼니를 판별한다. 밤 구간은 자정을 걸치므로 따로 처리한다.
MealPeriod currentMealPeriod([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 6 && hour < 12) return MealPeriod.breakfast;
  if (hour >= 12 && hour < 16) return MealPeriod.lunch;
  if (hour >= 16 && hour < 21) return MealPeriod.dinner;
  return MealPeriod.snack;
}

enum MealDecision { undecided, accepted, rejected }

class MealPeriodSummary {
  const MealPeriodSummary({
    required this.period,
    required this.label,
    required this.summary,
    this.isCurrent = false,
    this.imageUrl,
  });

  final MealPeriod period;
  final String label;
  final String summary;
  final bool isCurrent;
  final String? imageUrl;
}

class MealRecommendation {
  const MealRecommendation({
    required this.id,
    required this.period,
    required this.title,
    required this.description,
    required this.reasonTitle,
    required this.reason,
    required this.evidence,
    required this.nutritionTags,
    required this.cautions,
    this.imagePath,
    this.imageUrl,
  });

  final String id;
  final MealPeriod period;
  final String title;
  final String description;
  final String reasonTitle;
  final String reason;
  final String evidence;
  final List<String> nutritionTags;
  final List<MealCaution> cautions;
  final String? imagePath;
  final String? imageUrl;
}

class MealCaution {
  const MealCaution({
    required this.title,
    required this.description,
    this.badge,
  });

  final String title;
  final String description;
  final String? badge;
}

class MealGuideData {
  const MealGuideData({
    required this.greeting,
    required this.supportingText,
    required this.periods,
    required this.recommendations,
  });

  final String greeting;
  final String supportingText;
  final List<MealPeriodSummary> periods;
  final List<MealRecommendation> recommendations;

  MealRecommendation recommendationFor(MealPeriod period) {
    return recommendations.firstWhere((item) => item.period == period);
  }

  List<MealRecommendation> recommendationsFor(MealPeriod period) {
    return recommendations.where((item) => item.period == period).toList();
  }
}
