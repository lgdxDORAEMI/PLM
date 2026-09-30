import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/condition/data/api_condition_repository.dart';
import 'package:plm_frontend/features/condition/data/condition_repository.dart';
import 'package:plm_frontend/features/condition/data/mock_condition_repository.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';

const _draft = ConditionDraft(
  nausea: 2,
  waistPain: 4,
  pelvisPain: 3,
  legPain: 1,
  wristPain: 1,
  fatigue: 4,
  mood: 5,
);
final _date = DateTime(2026, 9, 18);

void main() {
  group('MockConditionRepository', () {
    test('저장 전에는 null, 저장 후에는 그 값을 돌려준다', () async {
      final repository = MockConditionRepository();

      expect(await repository.fetchToday(_date), isNull);

      await repository.saveToday(_date, _draft);
      final saved = await repository.fetchToday(_date);

      expect(saved?.nausea, 2);
      expect(saved?.mood, 5);
    });
  });

  group('ApiConditionRepository', () {
    test('GET 404는 null로 매핑된다(아직 저장 안 한 날짜)', () async {
      final client = ApiClient(
        httpClient: MockClient((request) async => http.Response('', 404)),
        baseUrl: 'http://test',
      );
      final repository = ApiConditionRepository(client);

      expect(await repository.fetchToday(_date), isNull);
    });

    test('GET 200은 snake_case 응답을 ConditionDraft로 변환한다', () async {
      final client = ApiClient(
        httpClient: MockClient(
          (request) async => http.Response(
            '{"nausea":2,"waist_pain":4,"pelvis_pain":3,"leg_pain":1,'
            '"wrist_pain":1,"fatigue":4,"mood":5,"target_date":"2026-09-18",'
            '"planned_activities":[],"changed_fields":[],"write_kind":"updated",'
            '"updated_at":"2026-09-18T00:00:00Z"}',
            200,
          ),
        ),
        baseUrl: 'http://test',
      );
      final repository = ApiConditionRepository(client);

      final result = await repository.fetchToday(_date);
      expect(result?.nausea, 2);
      expect(result?.mood, 5);
    });

    test('PUT은 /api/v1/care/conditions/{date}로 snake_case body를 보낸다', () async {
      late Uri capturedUri;
      late String capturedBody;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          capturedBody = request.body;
          return http.Response('{"nausea":2,"waist_pain":4,"pelvis_pain":3,'
              '"leg_pain":1,"wrist_pain":1,"fatigue":4,"mood":5,'
              '"target_date":"2026-09-18","planned_activities":[],'
              '"changed_fields":[],"write_kind":"created",'
              '"updated_at":"2026-09-18T00:00:00Z"}', 200);
        }),
        baseUrl: 'http://test',
      );
      final repository = ApiConditionRepository(client);

      await repository.saveToday(_date, _draft);

      expect(capturedUri.path, '/api/v1/care/conditions/2026-09-18');
      expect(capturedBody, contains('"waist_pain":4'));
      // Frontend는 daily_conditions 테이블명을 어디에도 담지 않는다(STEP 15).
      expect(capturedBody, isNot(contains('daily_conditions')));
    });

    test('4xx/5xx는 ApiException으로 변환된다', () async {
      final client = ApiClient(
        httpClient: MockClient(
          (request) async => http.Response(
            '{"detail":"컨디션을 먼저 저장해 주세요."}',
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: 'http://test',
      );
      final repository = ApiConditionRepository(client);

      expect(
        () => repository.saveToday(_date, _draft),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });

  group('TodayCareStore는 어떤 ConditionRepository를 주입해도 같은 동작을 보인다', () {
    for (final MapEntry(key: name, value: repository) in <String, ConditionRepository>{
      'Mock': MockConditionRepository(),
      'Api(성공만 흉내)': ApiConditionRepository(
        ApiClient(
          httpClient: MockClient(
            (request) async => http.Response(
              '{"nausea":2,"waist_pain":4,"pelvis_pain":3,"leg_pain":1,'
              '"wrist_pain":1,"fatigue":4,"mood":5,"target_date":"2026-09-18",'
              '"planned_activities":[],"changed_fields":[],"write_kind":"created",'
              '"updated_at":"2026-09-18T00:00:00Z"}',
              200,
            ),
          ),
          baseUrl: 'http://test',
        ),
      ),
    }.entries) {
      test('[$name] save() 직후 store.today에 즉시 반영된다(UI는 변경되지 않음)', () {
        final store = TodayCareStore.withRepository(repository);

        store.save(_draft);

        expect(store.today?.nausea, 2);
        expect(store.today?.mood, 5);
        expect(store.hasTodayCare, isTrue);
      });
    }
  });
}
