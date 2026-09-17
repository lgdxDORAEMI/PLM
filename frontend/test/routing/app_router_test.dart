import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/calendar/data/calendar_selection_store.dart';
import 'package:plm_frontend/features/condition/data/planned_activity_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/meal/data/meal_selection_store.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  setUp(() {
    TodayCareStore.instance.clear();
    PlannedActivityStore.instance.clear();
    MealSelectionStore.instance.clear();
    ProfileStore.instance.reset();
    CalendarSelectionStore.instance.reset();
  });

  const expectedRequirementIds = <String, String>{
    RouteNames.profileSetup: '프로필 설정',
    RouteNames.wifeProfile: '프로필 수정',
    RouteNames.partnerInvite: '남편도 ThinQ에 연결해보세요',
    RouteNames.wifeInvite: '남편도 ThinQ에 연결해보세요',
    '${RouteNames.partnerJoin}?token=test-token': '희선님이 함께 보자고 초대했어요',
    RouteNames.wifeMenu: '남편 초대하기',
    RouteNames.condition: '오늘의 컨디션',
    '${RouteNames.condition}?mode=edit': '오늘의 컨디션',
    RouteNames.activity: '오늘 할 집안일이 있나요?',
    RouteNames.wifeHome: '오늘 임신 28주차예요',
    RouteNames.mealGuide: '어떤 끼니를 볼까요?',
    RouteNames.householdGuide: '오늘은 허리 통증이 있는 날',
    RouteNames.wifeMovement: 'Phase 2 기능 미리보기',
    RouteNames.partnerMovement: 'Phase 2 기능 미리보기',
    RouteNames.healthGuide: '오늘의 집중 부위',
    RouteNames.sleepGuide: '오늘은 충분한 휴식이 필요해요',
    RouteNames.mealChat: '아침 메뉴를 다시 고르는 중',
    '/wife/report/2026-09-13': '오늘 루틴을 모두 마쳤어요',
    RouteNames.wifeCalendar: '2026년 9월',
    RouteNames.wifeSettings: '상세 요구사항이 확정될 때까지',
    '/partner/report/2026-09-13': '희선님은 임신 28주차예요',
    RouteNames.partnerCalendar: '2026년 9월',
    RouteNames.partnerNotifications: '읽지 않은 알림 2개',
    '/partner/requests/request-123': '희선님이 도움을 요청했어요',
  };

  testWidgets('ROUTE_MAP의 모든 내부 경로가 대응 화면을 만든다', (tester) async {
    for (final entry in expectedRequirementIds.entries) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(entry.key),
          initialRoute: entry.key,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(entry.value),
        findsOneWidget,
        reason: entry.key,
      );
    }
  });

  testWidgets('최초 프로필 등록을 완료하면 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.profileSetup,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );

    await tester.tap(find.byKey(const Key('due-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.textContaining('임신 전 신장·체중'), findsOneWidget);

    final bodyFields = find.byType(TextField);
    await tester.enterText(bodyFields.at(0), '165');
    await tester.enterText(bodyFields.at(1), '55');
    await _tapNext(tester);
    expect(find.text('첫 출산이신가요?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('초산이에요'));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.text('아기는 몇 명인가요?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('한 명이에요 (단태)'));
    await tester.pumpAndSettle();
    await _tapNext(tester);
    expect(find.text('알레르기가 있나요?'), findsOneWidget);
    await _tapNext(tester);
    expect(find.text('병원에서 주의받은 게 있나요?'), findsOneWidget);
    await _tapNext(tester);
    expect(find.text('입력한 내용을 확인해 주세요'), findsOneWidget);

    await tester.ensureVisible(find.text('완료하고 시작하기'));
    await tester.tap(find.text('완료하고 시작하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘 임신'), findsOneWidget);
  });

  testWidgets('동적 date와 requestId를 화면에 전달한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/partner/requests/request-123',
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('request-123'), findsOneWidget);
  });

  testWidgets('Profile 단계의 Back은 이전 입력 단계로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.profileSetup,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );

    await tester.tap(find.byKey(const Key('due-date-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _tapNext(tester);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();

    expect(find.text('출산예정일을 알려주세요'), findsOneWidget);
  });

  testWidgets('프로필 수정 직접 URL은 저장 후 Menu로 복귀한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeProfile,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 6; step += 1) {
      await _tapNext(tester);
    }
    await tester.ensureVisible(find.text('수정 완료'));
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();
    expect(find.text('남편 초대하기'), findsOneWidget);
  });

  testWidgets('아내 Shell은 서비스 흐름의 네 가지 하단 탭을 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsNWidgets(2));
    expect(find.text('실시간'), findsOneWidget);
    expect(find.text('챗봇'), findsOneWidget);
    expect(find.text('캘린더'), findsOneWidget);
  });

  testWidgets('Home에서 Today Care를 저장하면 루틴이 표시된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-today-care-button')));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 컨디션'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('입덧-2')));
    await tester.pumpAndSettle();
    expect(find.text('조금 있어요'), findsWidgets);

    final submit = find.byKey(const Key('today-care-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('오늘 할 집안일이 있나요?'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('오늘 루틴 만들기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('오늘 루틴 만들기'));
    await tester.pumpAndSettle();
    expect(TodayCareStore.instance.today?.nausea, 2);
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-routine-success')),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘의 하루 루틴'), findsOneWidget);
    expect(find.text('식사 가이드'), findsOneWidget);
  });

  testWidgets('Routine 카드가 Route Map의 각 Detail 화면으로 이동한다', (tester) async {
    const destinations = <String, String>{
      'meal': '어떤 끼니를 볼까요?',
      'household': '오늘은 허리 통증이 있는 날',
      'health': '오늘의 집중 부위',
      'sleep': '오늘은 충분한 휴식이 필요해요',
    };

    for (final destination in destinations.entries) {
      TodayCareStore.instance.save(const ConditionDraft());
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(destination.key),
          initialRoute: RouteNames.wifeHome,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(ValueKey('routine-card-${destination.key}'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // 하단 Navigation에 가리지 않도록 카드 중심을 안전 영역 안으로 옮긴다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(destination.value),
        findsOneWidget,
        reason: destination.key,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      TodayCareStore.instance.clear();
    }
  });

  testWidgets('Routine에서 Meal 재추천을 적용하고 Routine으로 복귀한다', (tester) async {
    TodayCareStore.instance.save(const ConditionDraft());
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();

    final mealCard = find.byKey(const ValueKey('routine-card-meal'));
    await tester.scrollUntilVisible(
      mealCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(mealCard);
    await tester.pumpAndSettle();
    expect(find.text('어떤 끼니를 볼까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meal-period-breakfast')));
    await tester.pumpAndSettle();
    expect(find.text('계란찜 + 누룽지'), findsOneWidget);

    final alternativeEntry = find.byKey(
      const ValueKey('meal-alternative-entry'),
    );
    await tester.scrollUntilVisible(
      alternativeEntry,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(alternativeEntry);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('meal-chat-prompt-속이 좀 메스꺼워요')));
    await tester.pumpAndSettle();

    final apply = find.byKey(const ValueKey('apply-meal-alternative'));
    await tester.scrollUntilVisible(
      apply,
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('meal-chat-log')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('찐 감자 + 플레인 요거트'), findsOneWidget);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(
      MealSelectionStore.instance.appliedRecommendation?.title,
      '찐 감자 + 플레인 요거트',
    );
    await tester.fling(
      find.byKey(const ValueKey('meal-recommendation-detail')),
      const Offset(0, 1000),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('찐 감자 + 플레인 요거트'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 끼니를 볼까요?'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('routine-card-meal')), findsOneWidget);
  });

  testWidgets('Today Care 변경 중 Back은 이탈 확인 후 Home으로 돌아간다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.wifeHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-today-care-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('입덧-2')));
    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('입력을 그만할까요?'), findsOneWidget);

    await tester.tap(find.text('계속 입력'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 컨디션'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-today-care-button')), findsOneWidget);
  });

  test('Bootstrap 상태가 역할별 시작 경로를 결정한다', () {
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.wifeNeedsProfile),
      RouteNames.entry,
    );
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.wifeReady),
      RouteNames.wifeHome,
    );
    expect(
      AppRouter.resolveLaunchRoute(AppLaunchState.partnerLinked),
      RouteNames.partnerCalendar,
    );
  });

  testWidgets('등록되지 않은 경로는 Entry로 복구한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/missing',
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREGNANCY LIFE MODE'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}

Future<void> _tapNext(WidgetTester tester) async {
  final button = find.text('다음');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
