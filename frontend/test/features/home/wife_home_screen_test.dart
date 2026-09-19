import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/home/screens/wife_home_screen.dart';
import 'package:plm_frontend/features/routine/models/daily_routine.dart';
import 'package:plm_frontend/features/routine/services/mock_routine_service.dart';
import 'package:plm_frontend/features/routine/services/routine_service.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  final conditionStore = TodayCareStore.instance;

  setUp(conditionStore.clear);
  tearDown(conditionStore.clear);

  testWidgets('컨디션 미입력 상태에는 Primary CTA만 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WifeHomeScreen()));

    expect(
      find.byKey(const ValueKey('home-condition-missing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-today-care-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-routine-success')), findsNothing);
  });

  testWidgets('컨디션 완료 후 Loading에서 Success와 Progress로 전환한다', (tester) async {
    await conditionStore.save(const ConditionDraft());
    final service = _ControlledRoutineService();

    await tester.pumpWidget(
      MaterialApp(home: WifeHomeScreen(routineService: service)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-condition-complete')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-routine-loading')), findsOneWidget);

    service.complete(MockRoutineService.todayPlan);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-routine-success')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('home-routine-success')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-edit-activities')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-routine-progress')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('home-routine-progress')), findsOneWidget);
  });

  testWidgets('Routine 실패 시 기본 가이드와 재시도를 표시한다', (tester) async {
    await conditionStore.save(const ConditionDraft());

    await tester.pumpWidget(
      const MaterialApp(
        home: WifeHomeScreen(routineService: _FailingRoutineService()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-routine-fallback')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('home-routine-fallback')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-routine-retry')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('routine-card-meal')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('routine-card-meal')), findsOneWidget);
  });
}

class _ControlledRoutineService implements RoutineService {
  final _completer = Completer<DailyRoutinePlan>();

  void complete(DailyRoutinePlan plan) => _completer.complete(plan);

  @override
  Future<DailyRoutinePlan> fetchToday() => _completer.future;
}

class _FailingRoutineService implements RoutineService {
  const _FailingRoutineService();

  @override
  Future<DailyRoutinePlan> fetchToday() {
    return Future.error(StateError('routine failure'));
  }
}
