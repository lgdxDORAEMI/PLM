import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/services/api_meal_service.dart';
import 'package:plm_frontend/features/meal/services/mock_meal_service.dart';

void main() {
  test('Guide item_id로 메뉴 거절 피드백을 전송한다', () async {
    http.Request? feedbackRequest;
    final service = ApiMealService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'items': [
                    {
                      'item_id': 'routine-item-42',
                      'title': '베리 요거트 귀리죽',
                      'payload': {
                        'period': 'breakfast',
                        'imagePath': 'breakfast/berry_yogurt_oatmeal.jpg',
                        'imageUrl':
                            'https://example.supabase.co/storage/v1/object/public/meal-images/breakfast/berry_yogurt_oatmeal.jpg',
                      },
                    },
                  ],
                }),
              ),
              200,
            );
          }
          feedbackRequest = request;
          return http.Response('{}', 200);
        }),
      ),
    );

    final recommendation = (await service.fetchGuide()).recommendations.single;
    await service.recordDecision(recommendation, MealDecision.rejected);

    expect(recommendation.id, 'routine-item-42');
    expect(recommendation.imagePath, 'breakfast/berry_yogurt_oatmeal.jpg');
    expect(
      recommendation.imageUrl,
      'https://example.supabase.co/storage/v1/object/public/meal-images/breakfast/berry_yogurt_oatmeal.jpg',
    );
    expect(feedbackRequest?.method, 'PUT');
    expect(
      feedbackRequest?.url.path,
      '/api/v1/care/routine-items/routine-item-42',
    );
    expect(jsonDecode(feedbackRequest!.body)['feedback_kind'], 'meal_reject');
  });

  test('없는 routine item은 성공으로 처리하지 않는다', () async {
    final service = ApiMealService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((_) async => http.Response('not found', 404)),
      ),
    );

    expect(
      () => service.recordDecision(
        MockMealService.guide.recommendations.first,
        MealDecision.rejected,
      ),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 404),
      ),
    );
  });

  test('대체 메뉴 선택은 전체 카드와 meal_replace로 저장한다', () async {
    http.Request? replacementRequest;
    final service = ApiMealService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          replacementRequest = request;
          return http.Response('{}', 200);
        }),
      ),
    );
    final recommendation = MealRecommendation(
      id: 'routine-item-42',
      period: MealPeriod.breakfast,
      title: '바나나 감자 찜',
      description: '속이 편해요',
      reasonTitle: '편안한 아침',
      reason: '속이 편해요',
      evidence: '',
      nutritionTags: const ['에너지'],
      cautions: const [],
      imagePath: 'snack/steamed_potato.jpg',
      imageUrl:
          'https://example.supabase.co/storage/v1/object/public/meal-images/snack/steamed_potato.jpg',
    );

    await service.replaceRecommendation(recommendation);

    final body = jsonDecode(replacementRequest!.body) as Map<String, dynamic>;
    expect(body['feedback_kind'], 'meal_replace');
    expect(body['payload']['title'], '바나나 감자 찜');
    expect(body['payload']['period'], 'breakfast');
    expect(body['payload']['nutritionTags'], ['에너지']);
    expect(body['payload']['imagePath'], 'snack/steamed_potato.jpg');
  });
}
