import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/sleep/screens/sleep_guide_screen.dart';

void main() {
  testWidgets('설정 화면을 열고 mock 수면 루틴을 시작한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SleepGuideScreen()));
    await tester.pumpAndSettle();

    final editButton = find.byKey(const ValueKey('sleep-edit-button'));
    await tester.scrollUntilVisible(
      editButton,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.text('수면 환경 설정'), findsOneWidget);

    await tester.tap(find.text('변경 완료'));
    await tester.pumpAndSettle();

    final startButton = find.byKey(const ValueKey('sleep-start-button'));
    await tester.scrollUntilVisible(
      startButton,
      -300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('환경 설정을 적용했어요'), findsOneWidget);
  });
}
