import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/services/api_meal_chat_service.dart';

void main() {
  test('일반 대화는 식사 이력을 제외하고 routine item 없이 전송한다', () async {
    http.Request? sent;
    final service = ApiMealChatService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode([
                  {
                    'message_id': '1',
                    'role': 'user',
                    'content': '일반 질문',
                    'routine_item_id': null,
                  },
                  {
                    'message_id': '2',
                    'role': 'user',
                    'content': '식사 질문',
                    'routine_item_id': 'meal-1',
                  },
                ]),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          sent = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'role': 'assistant', 'content': '생성된 답변'})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    expect((await service.fetchHistory()).single.text, '일반 질문');
    final reply = await service.sendMessage(current: null, message: '오늘은 어때요?');
    expect(reply.message, '생성된 답변');
    expect(jsonDecode(sent!.body), {'content': '오늘은 어때요?'});
  });

  test('식사 대화에는 실제 routine item id를 포함한다', () async {
    http.Request? sent;
    final service = ApiMealChatService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'role': 'assistant', 'content': '식사 답변'})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    )..routineItemId = 'meal-1';

    await service.sendMessage(current: null, message: '식사가 부담돼요');
    expect(jsonDecode(sent!.body)['routine_item_id'], 'meal-1');
  });

  test('컨디션 수정 확인과 상태 조회를 별도 API로 처리한다', () async {
    final requests = <http.Request>[];
    final service = ApiMealChatService(
      client: ApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: MockClient((request) async {
          requests.add(request);
          final status = request.method == 'GET' ? 'succeeded' : 'queued';
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'job_id': 'message-1',
                'status': status,
                'summary': '피로도를 5단계로 수정합니다.',
                'changes': [
                  {'field': 'fatigue', 'value': 5},
                ],
                if (status == 'succeeded') 'routine_revision': 2,
              }),
            ),
            request.method == 'POST' ? 202 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final queued = await service.decideRoutineUpdate(
      jobId: 'message-1',
      confirm: true,
    );
    final completed = await service.fetchRoutineUpdate('message-1');

    expect(queued.status.name, 'queued');
    expect(completed.routineRevision, 2);
    expect(jsonDecode(requests.first.body), {'action': 'confirm'});
    expect(
      requests.last.url.path,
      '/api/v1/chat/messages/message-1/routine-update',
    );
  });
  test('저장된 식사 추천 카드를 대화 이력에서 복원한다', () async {
    const context = MealRecommendation(
      id: 'meal-1',
      period: MealPeriod.breakfast,
      title: '기존 메뉴',
      description: '',
      reasonTitle: '추천 이유',
      reason: '',
      evidence: '',
      nutritionTags: [],
      cautions: [],
    );
    final service =
        ApiMealChatService(
            client: ApiClient(
              baseUrl: 'http://localhost:8000',
              httpClient: MockClient(
                (_) async => http.Response.bytes(
                  utf8.encode(
                    jsonEncode([
                      {
                        'message_id': 'assistant-1',
                        'role': 'assistant',
                        'content': '이 메뉴를 추천해요.',
                        'routine_item_id': 'meal-1',
                        'recommendation': {
                          'title': '두부 샐러드',
                          'reason': '담백하고 단백질을 보충할 수 있어요.',
                          'nutritionTags': ['단백질'],
                          'cautions': [],
                        },
                      },
                    ]),
                  ),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
          )
          ..routineItemId = 'meal-1'
          ..recommendationContext = context;

    final history = await service.fetchHistory();

    expect(history.single.recommendation?.title, '두부 샐러드');
    expect(history.single.recommendation?.period, MealPeriod.breakfast);
  });
}
