import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/sleep/screens/sleep_guide_screen.dart';
import 'package:plm_frontend/features/report/data/appliance_execution_store.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  setUp(ApplianceExecutionStore.instance.reset);

  testWidgets('환경 항목별 Sheet에서 추천값을 변경하고 전체 실행을 요청한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepGuideScreen()));
    await tester.pumpAndSettle();

    final heading = find.text('AI가 맞춘 오늘의 수면 환경');
    final headingRow = find
        .ancestor(of: heading, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: headingRow,
        matching: find.byKey(const ValueKey('sleep-run-all-button')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('sleep-environment-temperature')),
    );
    await tester.pumpAndSettle();
    expect(find.text('온도'), findsWidgets);
    expect(find.textContaining('원하는 값을 선택해 주세요.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sleep-option-temperature-23°C')),
    );
    await tester.tap(find.byKey(const ValueKey('sleep-apply-temperature')));
    await tester.pumpAndSettle();
    expect(find.text('23°C'), findsOneWidget);

    expect(find.text('탭하면 변경'), findsNothing);
    expect(find.textContaining('MVP 범위'), findsNothing);
    expect(find.textContaining('깼'), findsNothing);
    expect(find.textContaining('수면 루틴 실행은 준비 중'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sleep-run-all-button')));
    await tester.pumpAndSettle();
    expect(find.text('수면 루틴을 실행했습니다'), findsOneWidget);
    expect(find.textContaining('실제 기기는 작동하지 않아요'), findsNothing);
    expect(ApplianceExecutionStore.instance.forDate(DateTime.now()).length, 1);
  });

  testWidgets('공기청정기는 팀이 확정한 4개 라벨만 보여주고, 실제 제어는 전체 실행에서 한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepGuideScreen()));
    await tester.pumpAndSettle();

    final purifierCard = find.byKey(const ValueKey('sleep-environment-purifier'));
    await tester.ensureVisible(purifierCard);
    await tester.pumpAndSettle();
    await tester.tap(purifierCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sleep-option-purifier-조용 모드')), findsOneWidget);
    expect(find.byKey(const ValueKey('sleep-option-purifier-자동')), findsOneWidget);
    expect(find.byKey(const ValueKey('sleep-option-purifier-강풍')), findsOneWidget);
    expect(find.byKey(const ValueKey('sleep-option-purifier-끄기')), findsOneWidget);
    // 취침 예약(타이머)은 이번 범위에서 제외되어 목록에 없어야 한다.
    expect(find.byKey(const ValueKey('sleep-option-purifier-취침 예약')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sleep-option-purifier-강풍')));
    await tester.tap(find.byKey(const ValueKey('sleep-apply-purifier')));
    await tester.pumpAndSettle();

    // 적용하기는 선택만 저장한다 — 이 시점엔 아직 실기기를 제어하지 않는다.
    expect(find.text('강풍'), findsOneWidget);
    expect(find.text('공기청정기를 강풍(으)로 설정했어요'), findsNothing);

    // 목록이 가상화돼 있어 purifier까지 내려온 뒤엔 run-all 버튼이 트리에서 아예 빠진다 —
    // ensureVisible은 이미 트리에 있어야 동작하므로, 위로 드래그해서 다시 빌드시킨다.
    final runAllButton = find.byKey(const ValueKey('sleep-run-all-button'));
    await tester.dragUntilVisible(
      runAllButton,
      find.byKey(const ValueKey('sleep-guide-content')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.tap(runAllButton);
    await tester.pumpAndSettle();

    // 전체 실행에서 방금 고른 값(강풍)으로 실기기를 켠다.
    expect(find.text('수면 루틴을 실행했습니다'), findsOneWidget);
  });

  testWidgets('선택지를 바꿔 실행해도 (권장)은 AI 최초 추천값에 그대로 남는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepGuideScreen()));
    await tester.pumpAndSettle();

    final purifierCard = find.byKey(const ValueKey('sleep-environment-purifier'));
    await tester.ensureVisible(purifierCard);
    await tester.pumpAndSettle();
    await tester.tap(purifierCard);
    await tester.pumpAndSettle();

    // MockSleepService의 최초 AI 추천값은 '조용 모드'다.
    expect(find.text('조용 모드 (권장)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sleep-option-purifier-강풍')));
    await tester.tap(find.byKey(const ValueKey('sleep-apply-purifier')));
    await tester.pumpAndSettle();

    // 다시 열어도 '강풍'이 (권장)으로 옮겨붙지 않고, 최초 추천값에 그대로 남아야 한다.
    await tester.ensureVisible(purifierCard);
    await tester.pumpAndSettle();
    await tester.tap(purifierCard);
    await tester.pumpAndSettle();

    expect(find.text('조용 모드 (권장)'), findsOneWidget);
    expect(find.text('강풍 (권장)'), findsNothing);
  });
}
