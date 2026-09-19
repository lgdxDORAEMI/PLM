import '../../../core/network/api_client.dart';
import '../models/meal_guide.dart';
import 'meal_service.dart';

/// Shows meal recommendations from the saved routine items.
class ApiMealService implements MealService {
  ApiMealService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<MealGuideData> fetchGuide() async {
    final response = await _client.get('/api/v1/meals/today');
    if (response == null) {
      return const MealGuideData(
        greeting: '',
        supportingText: '',
        periods: [],
        recommendations: [],
      );
    }
    final items = response['items'];
    if (items is! List) throw const FormatException('식사 가이드 형식이 올바르지 않습니다.');
    final recommendations = <MealRecommendation>[];
    for (final raw in items.whereType<Map>()) {
      final payload = raw['payload'];
      final details = payload is Map ? payload : const {};
      final period = MealPeriod.values.firstWhere(
        (value) => value.name == details['period'],
        orElse: () => MealPeriod.breakfast,
      );
      final cautions = details['cautions'];
      recommendations.add(
        MealRecommendation(
          id:
              raw['item_key']?.toString() ??
              '${period.name}:${recommendations.length}',
          period: period,
          title: raw['title']?.toString() ?? '',
          description:
              raw['description']?.toString() ??
              details['reason']?.toString() ??
              '',
          reasonTitle: details['reasonTitle']?.toString() ?? '추천 이유',
          reason: details['reason']?.toString() ?? '',
          evidence: details['evidence']?.toString() ?? '',
          nutritionTags:
              (details['nutritionTags'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              const [],
          cautions: cautions is List
              ? cautions
                    .whereType<Map>()
                    .map(
                      (value) => MealCaution(
                        title: value['title']?.toString() ?? '',
                        description: value['description']?.toString() ?? '',
                      ),
                    )
                    .toList()
              : const [],
        ),
      );
    }
    final periods = <MealPeriodSummary>[];
    for (final period in MealPeriod.values) {
      final matches = recommendations.where((item) => item.period == period);
      if (matches.isEmpty) continue;
      periods.add(
        MealPeriodSummary(
          period: period,
          label: switch (period) {
            MealPeriod.breakfast => '아침',
            MealPeriod.lunch => '점심',
            MealPeriod.dinner => '저녁',
            MealPeriod.snack => '간식',
          },
          summary: matches.first.title,
        ),
      );
    }
    return MealGuideData(
      greeting: '오늘의 식사 가이드',
      supportingText: '오늘의 컨디션을 바탕으로 준비했어요.',
      periods: periods,
      recommendations: recommendations,
    );
  }

  @override
  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  }) => throw UnsupportedError('다른 메뉴를 불러오지 못했어요.');
}
