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
}
