import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/screens/condition_screen.dart';
import 'package:plm_frontend/features/condition/services/planned_activity_service.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
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

  testWidgets('안내 문구는 프로필 출산예정일로 계산한 주차를 보여준다', (tester) async {
    addTearDown(ProfileStore.instance.reset);
    final profile = ProfileDraft(
      dueDate: DateTime.now().add(const Duration(days: 140)),
    );
    ProfileStore.instance.save(profile);
    final week = profile.pregnancyWeekAt(DateTime.now());

    await tester.pumpWidget(
      const MaterialApp(home: ConditionScreen(mode: ConditionMode.create)),
    );

    expect(week, isNot(28));
    expect(find.text('10초면 끝나요 · 오늘 · 임신 $week주차'), findsOneWidget);
  });

  testWidgets('프로필이 없으면 주차 없이 안내한다', (tester) async {
    ProfileStore.instance.reset();

    await tester.pumpWidget(
      const MaterialApp(home: ConditionScreen(mode: ConditionMode.create)),
    );

    expect(find.text('10초면 끝나요 · 오늘'), findsOneWidget);
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
