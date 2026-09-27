import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/screens/condition_screen.dart';
import 'package:plm_frontend/features/condition/services/planned_activity_service.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  testWidgets('컨디션 수정 완료는 오늘 루틴 재생성까지 요청하고 홈으로 간다', (tester) async {
    final service = _CountingService();
    await tester.pumpWidget(
      MaterialApp(
        home: ConditionScreen(mode: ConditionMode.edit, service: service),
        routes: {RouteNames.wifeHome: (_) => const Text('홈')},
      ),
    );
    final done = find.text('수정 완료');
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    expect(service.generationCalls, 1);
    expect(find.text('홈'), findsOneWidget);
  });
}

class _CountingService implements PlannedActivityService {
  int generationCalls = 0;

  @override
  Future<List<String>> fetch(DateTime date) async => const [];

  @override
  Future<void> saveAndGenerate(DateTime date, List<String> activities) async {}

  @override
  Future<void> saveActivities(DateTime date, List<String> activities) async {}

  @override
  Future<void> generateRoutine() async => generationCalls += 1;
}
