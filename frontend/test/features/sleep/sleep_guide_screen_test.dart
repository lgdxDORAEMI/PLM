import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/sleep/screens/sleep_guide_screen.dart';

void main() {
  testWidgets('환경 항목별 Sheet에서 추천값을 변경하고 기기 실행은 비활성화한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepGuideScreen()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('sleep-environment-temperature')),
    );
    await tester.pumpAndSettle();
    expect(find.text('온도'), findsWidgets);
    expect(find.textContaining('기기 제어 없이'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sleep-option-temperature-23°C')),
    );
    await tester.tap(find.byKey(const ValueKey('sleep-apply-temperature')));
    await tester.pumpAndSettle();
    expect(find.text('23°C'), findsOneWidget);

    final startButton = find.byKey(const ValueKey('sleep-start-button'));
    await tester.scrollUntilVisible(
      startButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.descendant(of: startButton, matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });
}
