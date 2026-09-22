import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/components/app_button.dart';
import 'package:plm_frontend/features/condition/data/planned_activity_store.dart';
import 'package:plm_frontend/features/condition/screens/activity_screen.dart';
import 'package:plm_frontend/features/condition/services/planned_activity_service.dart';
import 'package:plm_frontend/features/profile/screens/partner_invite_screen.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  final store = PlannedActivityStore.instance;

  setUp(store.clear);
  tearDown(store.clear);

  testWidgets('예정 활동 수정 모드는 저장값과 수정 완료 버튼을 표시한다', (tester) async {
    store.save(const ['장보기', '베란다 정리']);

    await tester.pumpWidget(
      const MaterialApp(home: ActivityScreen(editing: true)),
    );

    expect(find.text('예정 활동 수정'), findsOneWidget);
    expect(find.textContaining('활동을 반영할게요'), findsNothing);
    expect(find.textContaining('Mock 루틴'), findsNothing);

    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('activity-장보기')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.selected, isTrue);

    await tester.scrollUntilVisible(
      find.text('베란다 정리'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('베란다 정리'), findsOneWidget);

    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('수정 완료'), findsOneWidget);
  });

  testWidgets('할 일 저장 후 초대를 거쳐야 루틴이 생성된다', (tester) async {
    final service = _PendingActivityService();
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(service: service),
        routes: {
          RouteNames.dailyInvite: (_) => PartnerInviteScreen(
            entryContext: InviteEntryContext.dailyFlow,
            activityService: service,
          ),
          RouteNames.wifeHome: (_) => const Scaffold(body: Text('홈 도착')),
        },
      ),
    );
    await tester.pump();
    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PartnerInviteScreen), findsOneWidget);
    expect(service.savedActivities, isTrue);
    expect(service.generationCalls, 0);
    await tester.scrollUntilVisible(
      find.text('나중에'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('나중에'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pump();
    expect(find.text('AI 루틴 생성중...'), findsOneWidget);
    expect(service.generationCalls, 1);
    expect(find.text('홈 도착'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('AI 루틴 생성중...'), findsOneWidget);

    service.complete();
    await tester.pumpAndSettle();
    expect(find.text('AI 루틴 생성중...'), findsNothing);
    expect(find.text('홈 도착'), findsOneWidget);
  });

  testWidgets('루틴 생성 실패 시 로딩 창을 닫고 다시 시도할 수 있다', (tester) async {
    final service = _PendingActivityService();
    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(editing: true, service: service)),
    );
    await tester.pump();
    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pump();

    service.fail();
    await tester.pumpAndSettle();
    expect(find.text('AI 루틴 생성중...'), findsNothing);
    expect(find.text('오늘의 루틴을 만들지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(tester.widget<AppButton>(submit).onPressed, isNotNull);
  });

  testWidgets('초기화 후 할 일 입력은 초대 화면 없이 루틴을 생성한다', (tester) async {
    final profile = ProfileStore.instance;
    profile.requireReentry();
    profile.completeReentry();
    addTearDown(profile.completeResetRoutine);
    final service = _PendingActivityService();
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(service: service),
        routes: {
          RouteNames.wifeHome: (_) => const Scaffold(body: Text('홈 도착')),
        },
      ),
    );
    await tester.pump();
    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI 루틴 만들기'), findsOneWidget);
    await tester.tap(submit);
    await tester.pump();
    expect(service.generationCalls, 1);
    expect(profile.awaitsResetRoutine, isTrue);
    service.complete();
    await tester.pumpAndSettle();
    expect(find.text('홈 도착'), findsOneWidget);
    expect(profile.awaitsResetRoutine, isFalse);
  });
}

class _PendingActivityService implements PlannedActivityService {
  final Completer<void> _generation = Completer<void>();
  bool savedActivities = false;
  int generationCalls = 0;

  @override
  Future<List<String>> fetch(DateTime date) async => const [];

  @override
  Future<void> saveAndGenerate(DateTime date, List<String> activities) {
    savedActivities = true;
    generationCalls += 1;
    return _generation.future;
  }

  @override
  Future<void> saveActivities(DateTime date, List<String> activities) async {
    savedActivities = true;
  }

  @override
  Future<void> generateRoutine() {
    generationCalls += 1;
    return _generation.future;
  }

  void complete() => _generation.complete();

  void fail() => _generation.completeError(StateError('generation failed'));
}
