import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/home/screens/wife_home_screen.dart';
import 'package:plm_frontend/features/home/models/home_week_context.dart';
import 'package:plm_frontend/features/home/services/home_week_service.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
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

  testWidgets('주차별 안내를 최상단 초록 배너 안에 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WifeHomeScreen(homeWeekService: _FakeHomeWeekService()),
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('home-week-hero'));
    expect(hero, findsOneWidget);
    expect(
      find.ancestor(of: _findWeekText('주차 안내 첫 번째'), matching: hero),
      findsOneWidget,
    );
    expect(_findWeekText('주차 안내 두 번째'), findsOneWidget);
    expect(_findWeekText('주차 주의사항'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-week-tip')), findsNothing);
  });

  testWidgets('실연동 주차 데이터가 비어도 연동 필요 메시지로 오인하지 않는다', (tester) async {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    addTearDown(ProfileStore.instance.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: WifeHomeScreen(homeWeekService: _EmptyHomeWeekService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('주차별 안내를 준비하지 못했어요'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.text('연동이 필요합니다'), findsNothing);
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
    expect(find.text(MockRoutineService.todayPlan.updatedLabel), findsNothing);
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
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false}) =>
      _completer.future;
}

class _FailingRoutineService implements RoutineService {
  const _FailingRoutineService();

  @override
  Future<DailyRoutinePlan> fetchToday({bool forceRefresh = false}) {
    return Future.error(StateError('routine failure'));
  }
}

class _FakeHomeWeekService implements HomeWeekService {
  const _FakeHomeWeekService();

  @override
  Future<HomeWeekContext> fetch() async => const HomeWeekContext(
    week: 28,
    notes: ['주차 안내 첫 번째', '주차 안내 두 번째'],
    caution: '주차 주의사항',
  );
}

class _EmptyHomeWeekService implements HomeWeekService {
  const _EmptyHomeWeekService();

  @override
  Future<HomeWeekContext> fetch() async =>
      const HomeWeekContext(week: null, notes: [], caution: null);
}

/// 주차 히어로는 어절 단위 줄바꿈을 위해 글자 사이에 U+2060을 넣으므로 이를 빼고 비교한다.
Finder _findWeekText(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.data?.replaceAll('\u2060', '') == text,
);
