import '../../../core/network/api_client.dart';
import '../models/meal_guide.dart';
import 'meal_service.dart';

/// Shows meal recommendations from the saved routine items.
class ApiMealService implements MealService {
  ApiMealService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  ) async {
    if (decision == MealDecision.undecided) return;
    await _client.put(
      '/api/v1/care/routine-items/${Uri.encodeComponent(recommendation.id)}',
      {
        'payload': {'title': recommendation.title},
        'feedback_kind': decision == MealDecision.accepted
            ? 'meal_accept'
            : 'meal_reject',
      },
      true,
    );
  }

  @override
  Future<MealGuideData> fetchGuide() async {
    final response = await _client.get(
      '/api/v1/meals/today',
      throwOnNotFound: true,
    );
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
      final itemId = raw['item_id']?.toString() ?? '';
      if (itemId.isEmpty) {
        throw const FormatException('식사 가이드에 item_id가 없습니다.');
      }
      final payload = raw['payload'];
      final details = payload is Map ? payload : const {};
      final period = MealPeriod.values.firstWhere(
        (value) => value.name == details['period'],
        orElse: () => MealPeriod.breakfast,
      );
      final cautions = details['cautions'];
      recommendations.add(
        MealRecommendation(
          id: itemId,
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
            MealPeriod.snack => '밤',
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

  /// 식사 가이드 '다른 메뉴 보기'(09-22). Backend가 조건에 맞는 새 메뉴 1개를 만든다.
  /// 같은 routine_item을 가리키도록 id는 그대로 두어, 선택·거절 기록이 원래 끼니 항목에 남는다.
  @override
  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  }) async {
    final response = await _client.post('/api/v1/chat/meal-alternative', {
      'routine_item_id': current.id,
      'request': request,
    });
    final title = response?['title'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('다른 메뉴 형식이 올바르지 않습니다.');
    }
    final reason = response?['reason']?.toString() ?? '';
    final cautions = response?['cautions'];
    return MealRecommendation(
      id: current.id,
      period: current.period,
      title: title,
      description: reason,
      reasonTitle: current.reasonTitle,
      reason: reason,
      evidence: '',
      nutritionTags:
          (response?['nutritionTags'] as List?)?.whereType<String>().toList() ??
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
    );
  }
}
