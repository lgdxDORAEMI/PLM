import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';

void main() {
  test('401이면 세션을 한 번 갱신하고 새 토큰으로 요청을 재시도한다', () async {
    var token = 'expired-token';
    var refreshCalls = 0;
    final authorizationHeaders = <String?>[];
    final client = ApiClient(
      baseUrl: 'https://api.example.com',
      accessTokenProvider: () => token,
      sessionRefresher: () async {
        refreshCalls += 1;
        token = 'fresh-token';
        return true;
      },
      httpClient: MockClient((request) async {
        authorizationHeaders.add(request.headers['authorization']);
        if (authorizationHeaders.length == 1) {
          return http.Response(
            jsonEncode({'detail': '로그인이 필요합니다.'}),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    final response = await client.get('/health');

    expect(response, {'status': 'ok'});
    expect(refreshCalls, 1);
    expect(authorizationHeaders, [
      'Bearer expired-token',
      'Bearer fresh-token',
    ]);
  });

  test('세션 갱신에 실패하면 원래 401을 그대로 전달한다', () async {
    var requestCalls = 0;
    final client = ApiClient(
      baseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'expired-token',
      sessionRefresher: () async => false,
      httpClient: MockClient((request) async {
        requestCalls += 1;
        return http.Response(
          jsonEncode({'detail': '로그인이 필요합니다.'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.get('/profile'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', '로그인이 필요합니다.'),
      ),
    );
    expect(requestCalls, 1);
  });

  test('토큰이 없는 401은 세션 갱신을 시도하지 않는다', () async {
    var refreshCalls = 0;
    final client = ApiClient(
      baseUrl: 'https://api.example.com',
      accessTokenProvider: () => null,
      sessionRefresher: () async {
        refreshCalls += 1;
        return true;
      },
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'detail': '로그인이 필요합니다.'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(client.get('/profile'), throwsA(isA<ApiException>()));
    expect(refreshCalls, 0);
  });
}
