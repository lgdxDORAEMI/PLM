import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
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
}
