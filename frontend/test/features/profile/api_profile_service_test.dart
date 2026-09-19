import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plm_frontend/core/network/api_client.dart';
import 'package:plm_frontend/features/profile/data/api_profile_service.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';

void main() {
  test('Profile save follows the six backend endpoints in order', () async {
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final client = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', 200);
      }),
    );
    final service = ApiProfileService(client: client);

    await service.save(
      ProfileDraft(
        dueDate: DateTime(2027, 1, 20),
        birthDate: DateTime(1993, 5, 14),
        height: '165',
        prePregnancyWeight: '55',
        isFirstPregnancy: true,
        isMultiplePregnancy: false,
        medicalConditions: const {'없어요'},
      ),
    );

    expect(paths, [
      '/api/v1/profile/me/due-date',
      '/api/v1/profile/me/body',
      '/api/v1/profile/me/pregnancy-history',
      '/api/v1/profile/me/pregnancy-count',
      '/api/v1/profile/me/allergies',
      '/api/v1/profile/me/medical-notes',
    ]);
    expect(bodies.last['medical_conditions'], isEmpty);
    expect(bodies.expand((body) => body.keys), isNot(contains('birth_date')));
  });
}
